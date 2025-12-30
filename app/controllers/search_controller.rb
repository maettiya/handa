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

    # Search both top-level Projects and individual ProjectFiles
    @projects = current_user.projects
    @files = current_user.project_files.visible
      .where("NOT (parent_id IS NULL AND is_directory = ?)", true)  # Exclude root-level directories

    # Apply text search if query present
    if @query.present?
      @projects = @projects.where("LOWER(projects.title) LIKE ?", "%#{@query.downcase}%")
      @files = @files.where("LOWER(project_files.original_filename) LIKE ?", "%#{@query.downcase}%")
    end

    # Apply date range filter (only when BOTH dates are present)
    if @date_range_active
      date_from = Date.parse(@date_from) rescue nil
      date_to = Date.parse(@date_to) rescue nil

      if date_from
        @projects = @projects.where("projects.created_at >= ?", date_from.beginning_of_day)
        @files = @files.where("project_files.created_at >= ?", date_from.beginning_of_day)
      end

      if date_to
        @projects = @projects.where("projects.created_at <= ?", date_to.end_of_day)
        @files = @files.where("project_files.created_at <= ?", date_to.end_of_day)
      end
    end

    # Apply sorting BEFORE BPM/Key filtering (which converts to Array)
    # Only apply sorting if user explicitly selected one
    if @sort.present?
      case @sort
      when 'recent'
        @projects = @projects.order("projects.created_at DESC")
        @files = @files.order("project_files.created_at DESC")
      when 'oldest'
        @projects = @projects.order("projects.created_at ASC")
        @files = @files.order("project_files.created_at ASC")
      when 'a-z'
        @projects = @projects.order(Arel.sql("LOWER(projects.title) ASC"))
        @files = @files.order(Arel.sql("LOWER(project_files.original_filename) ASC"))
      when 'z-a'
        @projects = @projects.order(Arel.sql("LOWER(projects.title) DESC"))
        @files = @files.order(Arel.sql("LOWER(project_files.original_filename) DESC"))
      end
    end

    # Limit results before converting to array
    @projects = @projects.limit(50).to_a
    @files = @files.limit(150).to_a

    # Apply BPM filter (extracted from filename) - works on arrays
    if @bpm_mode == 'exact' && @bpm_exact.present?
      @files = filter_by_bpm_exact(@files, @bpm_exact.to_i)
      @projects = filter_by_bpm(@projects, @bpm_exact.to_i, :exact)
    elsif @bpm_range_active
      # Only filter when BOTH min and max are present
      @files = filter_by_bpm_range(@files, @bpm_min, @bpm_max)
      @projects = filter_by_bpm(@projects, [@bpm_min.to_i, @bpm_max.to_i], :range)
    end

    # Apply key filter (extracted from filename) - works on arrays
    if @key.present?
      @files = filter_by_key(@files, @key)
      @projects = filter_projects_by_key(@projects, @key)
    end

    # Split into categories:
    # 1. DAW - Individual .als, .logicx files (excluding Backup folders)
    # 2. Audio & Files - Everything else (Projects, audio files, folders, other files)

    daw_extensions = %w[als logicx flp ptx]

    # Get IDs of all "Backup" folders for the current user
    backup_folder_ids = current_user.project_files.where(is_directory: true)
      .where("LOWER(original_filename) = 'backup'")
      .pluck(:id)

    # DAW Files = .als, .logicx, etc files (excluding Backup folder contents)
    @daw_files = @files.select do |file|
      next false if file.is_directory
      next false if backup_folder_ids.include?(file.parent_id)
      daw_extensions.include?(file.extension)
    end

    # Audio & other files = everything else (directories, audio, misc files)
    @audio_files = @files.reject do |file|
      next false if file.is_directory  # Keep directories
      next true if backup_folder_ids.include?(file.parent_id) && daw_extensions.include?(file.extension)
      daw_extensions.include?(file.extension)  # Exclude DAW files
    end

    # All top-level Projects go to Audio & Files section
    @other_projects = @projects
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
  # Handles many naming conventions:
  # - "E Minor", "Em", "em", "EM", "EMinor", "Eminor", "eminor", "e minor", "EMin", "emin", "Emin", "EMIN"
  # - Notes with accidentals: "C#m", "Ebmaj", "F# Minor"
  # - "Flat" naming: "A flat Minor", "A_flat_min", "A FLAT MIN", "Aflat", "A-flat"
  # - Parentheses: "(E Minor - 83 BPM)", "(A flat Minor - 96 BPM)"
  # IMPORTANT: Key must be standalone - "GREMLIN" should NOT match "Em", but "GREMLIN_EM" SHOULD
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
    # Order matters: check longer patterns first
    minor_patterns = ['minor', 'min', 'm']
    major_patterns = ['major', 'maj']

    # FIRST: Check for "flat" naming convention (e.g., "A flat Minor", "A_flat_min", "A FLAT")
    # This catches patterns like: A flat, A_flat, A-flat, Aflat followed by mode
    simple_notes.each do |note|
      flat_note = flat_notes[note]

      # Pattern for "A flat minor", "A_flat_min", "A-flat-minor", "A FLAT MIN", "Aflat minor"
      # Allows: space, underscore, hyphen, or nothing between note and "flat"
      # Then optional separator and mode
      minor_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)])#{note}[\s_\-]?flat[\s_\-]?#{mode}(?:[\s_\-\.\(\)]|$)/i
        if filename.match?(pattern)
          return "#{flat_note}m"
        end
      end

      major_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)])#{note}[\s_\-]?flat[\s_\-]?#{mode}(?:[\s_\-\.\(\)]|$)/i
        if filename.match?(pattern)
          return flat_note
        end
      end
    end

    # SECOND: Check for standard accidental notation (Ab, Bb, C#, etc.)
    notes_with_accidentals.each do |note|
      # Check for minor: C#m, C#min, C#minor, C# Minor, C# m, etc.
      minor_patterns.each do |mode|
        # Pattern: note + optional space + mode + word boundary
        # The mode must be followed by a non-letter (or end of string)
        pattern = /(?:^|[\s_\-\.\(\)])#{Regexp.escape(note)}\s*#{mode}(?:[\s_\-\.\(\)]|$)/i
        if filename.match?(pattern)
          return "#{note}m"
        end
      end

      # Check for major: C#maj, C#major, C# Major, etc.
      major_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)])#{Regexp.escape(note)}\s*#{mode}(?:[\s_\-\.\(\)]|$)/i
        if filename.match?(pattern)
          return note
        end
      end
    end

    # THIRD: Try simple notes (A-G) - requires word boundary to avoid false positives
    simple_notes.each do |note|
      # For simple notes, we need stricter boundaries
      # Must be preceded by: start, space, underscore, hyphen, dot, or parenthesis
      # For minor: Em, Emin, Eminor, E Minor, E min, etc.
      # Must be followed by: end, space, underscore, hyphen, dot, parenthesis, or next word

      minor_patterns.each do |mode|
        # Different pattern for single 'm' vs 'min'/'minor' to avoid false positives
        if mode == 'm'
          # For just 'm', need to ensure it's not part of a word
          # Match: _Em_, (Em), Em.wav, " Em ", etc. but NOT "GREMLIN"
          pattern = /(?:^|[\s_\-\.\(\)])#{note}m(?:[\s_\-\.\(\)]|$)/i
          if filename.match?(pattern)
            return "#{note}m"
          end
        else
          # For 'min' and 'minor', more permissive since they're explicit
          pattern = /(?:^|[\s_\-\.\(\)])#{note}\s*#{mode}(?:[\s_\-\.\(\)]|$)/i
          if filename.match?(pattern)
            return "#{note}m"
          end
        end
      end

      # For major: Emaj, Emajor, E Major, E maj, etc.
      major_patterns.each do |mode|
        pattern = /(?:^|[\s_\-\.\(\)])#{note}\s*#{mode}(?:[\s_\-\.\(\)]|$)/i
        if filename.match?(pattern)
          return note
        end
      end
    end

    nil
  end

  def filter_by_bpm_exact(files, bpm)
    return files if bpm.nil? || bpm <= 0

    files.select do |file|
      extracted_bpm = extract_bpm(file.original_filename)
      extracted_bpm == bpm
    end
  end

  def filter_by_bpm_range(files, min_bpm, max_bpm)
    min_bpm = min_bpm.to_i if min_bpm.present?
    max_bpm = max_bpm.to_i if max_bpm.present?

    files.select do |file|
      bpm = extract_bpm(file.original_filename)
      next false unless bpm

      in_range = true
      in_range &&= bpm >= min_bpm if min_bpm.present? && min_bpm > 0
      in_range &&= bpm <= max_bpm if max_bpm.present? && max_bpm > 0
      in_range
    end
  end

  def filter_by_key(files, key)
    key_normalized = normalize_key(key)
    return files if key_normalized.nil?

    files.select do |file|
      extracted = extract_key(file.original_filename)
      next false unless extracted
      normalize_key(extracted) == key_normalized
    end
  end

  # Filter Projects by BPM (from title)
  def filter_by_bpm(projects, bpm_value, mode)
    projects.select do |project|
      extracted_bpm = extract_bpm(project.title)
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

  # Filter Projects by Key (from title)
  def filter_projects_by_key(projects, key)
    key_normalized = normalize_key(key)
    return projects if key_normalized.nil?

    projects.select do |project|
      extracted = extract_key(project.title)
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
