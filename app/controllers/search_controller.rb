class SearchController < ApplicationController
  before_action :authenticate_user!

  def index
    @query = params[:q].to_s.strip
    @sort = params[:sort]  # nil by default, no forced sorting
    @date_from = params[:date_from]
    @date_to = params[:date_to]
    @bpm_mode = params[:bpm_mode] || 'range'  # 'exact' or 'range'
    @bpm_exact = params[:bpm_exact]
    @bpm_min = params[:bpm_min]
    @bpm_max = params[:bpm_max]
    @key = params[:key]

    # BPM range only active when BOTH min AND max are filled
    @bpm_range_active = @bpm_min.present? && @bpm_max.present?
    # Date range only active when BOTH from AND to are filled
    @date_range_active = @date_from.present? && @date_to.present?

    # Check if any filter is active (with new range requirements)
    # Sort by alone should also show results
    @has_filters = @query.present? || @date_range_active || @sort.present? ||
                   (@bpm_mode == 'exact' && @bpm_exact.present?) || @bpm_range_active || @key.present?

    # Search both root-level assets and child assets
    @root_assets = current_user.assets.root_level
    @child_assets = current_user.assets.visible
      .where.not(parent_id: nil)  # Only children
      .where("NOT (parent_id IS NOT NULL AND is_directory = ?)", true)  # Exclude nested directories

    # Apply text search if query present
    if @query.present?
      @root_assets = @root_assets.where("LOWER(assets.title) LIKE ?", "%#{@query.downcase}%")
      @child_assets = @child_assets.where("LOWER(assets.original_filename) LIKE ?", "%#{@query.downcase}%")
    end

    # Apply date range filter (only when BOTH dates are present)
    if @date_range_active
      date_from = Date.parse(@date_from) rescue nil
      date_to = Date.parse(@date_to) rescue nil

      if date_from
        @root_assets = @root_assets.where("assets.created_at >= ?", date_from.beginning_of_day)
        @child_assets = @child_assets.where("assets.created_at >= ?", date_from.beginning_of_day)
      end

      if date_to
        @root_assets = @root_assets.where("assets.created_at <= ?", date_to.end_of_day)
        @child_assets = @child_assets.where("assets.created_at <= ?", date_to.end_of_day)
      end
    end

    # Apply sorting BEFORE BPM/Key filtering (which converts to Array)
    # Only apply sorting if user explicitly selected one
    if @sort.present?
      case @sort
      when 'recent'
        @root_assets = @root_assets.order("assets.created_at DESC")
        @child_assets = @child_assets.order("assets.created_at DESC")
      when 'oldest'
        @root_assets = @root_assets.order("assets.created_at ASC")
        @child_assets = @child_assets.order("assets.created_at ASC")
      when 'a-z'
        @root_assets = @root_assets.order(Arel.sql("LOWER(assets.title) ASC"))
        @child_assets = @child_assets.order(Arel.sql("LOWER(assets.original_filename) ASC"))
      when 'z-a'
        @root_assets = @root_assets.order(Arel.sql("LOWER(assets.title) DESC"))
        @child_assets = @child_assets.order(Arel.sql("LOWER(assets.original_filename) DESC"))
      end
    end

    # Limit results before converting to array
    @root_assets = @root_assets.limit(50).to_a
    @child_assets = @child_assets.limit(150).to_a

    # Apply BPM filter (extracted from filename) - works on arrays
    if @bpm_mode == 'exact' && @bpm_exact.present?
      @child_assets = filter_by_bpm_exact(@child_assets, @bpm_exact.to_i)
      @root_assets = filter_by_bpm(@root_assets, @bpm_exact.to_i, :exact)
    elsif @bpm_range_active
      # Only filter when BOTH min and max are present
      @child_assets = filter_by_bpm_range(@child_assets, @bpm_min, @bpm_max)
      @root_assets = filter_by_bpm(@root_assets, [@bpm_min.to_i, @bpm_max.to_i], :range)
    end

    # Apply key filter (extracted from filename) - works on arrays
    if @key.present?
      @child_assets = filter_by_key(@child_assets, @key)
      @root_assets = filter_root_assets_by_key(@root_assets, @key)
    end

    # Split into categories:
    # 1. DAW - Individual .als, .logicx files (excluding Backup folders)
    # 2. Audio & Files - Everything else (root assets, audio files, folders, other files)

    daw_extensions = %w[als logicx flp ptx]

    # Get IDs of all "Backup" folders for the current user
    backup_folder_ids = current_user.assets.where(is_directory: true)
      .where("LOWER(original_filename) = 'backup'")
      .pluck(:id)

    # DAW Files = .als, .logicx, etc files (excluding Backup folder contents)
    @daw_files = @child_assets.select do |asset|
      next false if asset.is_directory?
      next false if backup_folder_ids.include?(asset.parent_id)
      daw_extensions.include?(asset.extension)
    end

    # Audio & other files = everything else (directories, audio, misc files)
    @audio_files = @child_assets.reject do |asset|
      next false if asset.is_directory?  # Keep directories
      next true if backup_folder_ids.include?(asset.parent_id) && daw_extensions.include?(asset.extension)
      daw_extensions.include?(asset.extension)  # Exclude DAW files
    end

    # All root-level assets go to Audio & Files section
    @other_projects = @root_assets
  end

  private

  # Extract BPM from filename using regex
  # Matches patterns like: "74bpm", "74.5 bpm", "79.92BPM", "BPM 74", etc.
  # Returns the integer part (floor) so 76.88 -> 76, 79.92 -> 79
  def extract_bpm(filename)
    patterns = [
      /(\d{2,3}(?:\.\d+)?)\s*bpm/i,      # 74bpm, 74.5 bpm, 79.92BPM
      /bpm\s*(\d{2,3}(?:\.\d+)?)/i,      # bpm74, BPM 74.5
      /(\d{2,3}(?:\.\d+)?)\s*tempo/i,    # 74tempo, 74.5tempo
      /_(\d{2,3})_/,                      # _74_ (common separator pattern, integers only)
    ]

    patterns.each do |pattern|
      match = filename.match(pattern)
      return match[1].to_f.floor if match  # Floor to integer (76.88 -> 76)
    end

    nil
  end

  # Extract musical key from filename
  def extract_key(filename)
    # Map of "flat" note names to their standard notation
    flat_notes = {
      'A' => 'Ab', 'B' => 'Bb', 'C' => 'Cb', 'D' => 'Db',
      'E' => 'Eb', 'F' => 'Fb', 'G' => 'Gb'
    }

    # Notes with accidentals (check first - more specific)
    notes_with_accidentals = %w[Ab A# Bb Cb C# Db D# Eb Fb F# Gb G#]
    # Simple notes
    simple_notes = %w[A B C D E F G]

    # Mode patterns - covers: minor, min, m, major, maj
    minor_patterns = ['minor', 'min', 'm']
    major_patterns = ['major', 'maj']

    # FIRST: Check for "flat" naming convention
    simple_notes.each do |note|
      flat_note = flat_notes[note]

      minor_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)\[\]])#{note}[\s_\-]?flat[\s_\-]?#{mode}(?:[\s_\-\.\(\)\[\]]|$)/i
        if filename.match?(pattern)
          return "#{flat_note}m"
        end
      end

      major_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)\[\]])#{note}[\s_\-]?flat[\s_\-]?#{mode}(?:[\s_\-\.\(\)\[\]]|$)/i
        if filename.match?(pattern)
          return flat_note
        end
      end
    end

    # SECOND: Check for standard accidental notation (Ab, Bb, C#, etc.)
    notes_with_accidentals.each do |note|
      minor_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)\[\]])#{Regexp.escape(note)}\s*#{mode}(?:[\s_\-\.\(\)\[\]]|$)/i
        if filename.match?(pattern)
          return "#{note}m"
        end
      end

      major_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)\[\]])#{Regexp.escape(note)}\s*#{mode}(?:[\s_\-\.\(\)\[\]]|$)/i
        if filename.match?(pattern)
          return note
        end
      end
    end

    # THIRD: Try simple notes (A-G)
    simple_notes.each do |note|
      minor_patterns.each do |mode|
        if mode == 'm'
          pattern = /(?:^|[\s_\-\.\(\)\[\]])#{note}m(?:[\s_\-\.\(\)\[\]]|$)/i
          if filename.match?(pattern)
            return "#{note}m"
          end
        else
          pattern = /(?:^|[\s_\-\.\(\)\[\]])#{note}\s*#{mode}(?:[\s_\-\.\(\)\[\]]|$)/i
          if filename.match?(pattern)
            return "#{note}m"
          end
        end
      end

      major_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)\[\]])#{note}\s*#{mode}(?:[\s_\-\.\(\)\[\]]|$)/i
        if filename.match?(pattern)
          return note
        end
      end
    end

    nil
  end

  def filter_by_bpm_exact(assets, bpm)
    return assets if bpm.nil? || bpm <= 0

    assets.select do |asset|
      extracted_bpm = extract_bpm(asset.original_filename)
      extracted_bpm == bpm
    end
  end

  def filter_by_bpm_range(assets, min_bpm, max_bpm)
    min_bpm = min_bpm.to_i if min_bpm.present?
    max_bpm = max_bpm.to_i if max_bpm.present?

    assets.select do |asset|
      bpm = extract_bpm(asset.original_filename)
      next false unless bpm

      in_range = true
      in_range &&= bpm >= min_bpm if min_bpm.present? && min_bpm > 0
      in_range &&= bpm <= max_bpm if max_bpm.present? && max_bpm > 0
      in_range
    end
  end

  def filter_by_key(assets, key)
    key_normalized = normalize_key(key)
    return assets if key_normalized.nil?

    assets.select do |asset|
      extracted = extract_key(asset.original_filename)
      next false unless extracted
      normalize_key(extracted) == key_normalized
    end
  end

  # Filter root assets by BPM (from title)
  def filter_by_bpm(assets, bpm_value, mode)
    assets.select do |asset|
      extracted_bpm = extract_bpm(asset.title)
      next false unless extracted_bpm

      if mode == :exact
        extracted_bpm == bpm_value
      else
        min_bpm, max_bpm = bpm_value
        in_range = true
        in_range &&= extracted_bpm >= min_bpm if min_bpm > 0
        in_range &&= extracted_bpm <= max_bpm if max_bpm > 0
        in_range
      end
    end
  end

  # Filter root assets by Key (from title)
  def filter_root_assets_by_key(assets, key)
    key_normalized = normalize_key(key)
    return assets if key_normalized.nil?

    assets.select do |asset|
      extracted = extract_key(asset.title)
      next false unless extracted
      normalize_key(extracted) == key_normalized
    end
  end

  def normalize_key(key)
    return nil if key.blank?

    key = key.to_s.strip
    if key.match?(/min|minor/i) || key.match?(/[A-G][#b]?m$/i)
      note = key.gsub(/\s*(min|minor|m).*$/i, '').strip
      "#{note}m"
    else
      key.gsub(/\s*(maj|major).*$/i, '').strip
    end
  end
end
