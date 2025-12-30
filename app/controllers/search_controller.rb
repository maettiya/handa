class SearchController < ApplicationController
  before_action :authenticate_user!

  def index
    @query = params[:q].to_s.strip
    @sort = params[:sort] || 'recent'
    @date_from = params[:date_from]
    @date_to = params[:date_to]
    @bpm_min = params[:bpm_min]
    @bpm_max = params[:bpm_max]
    @key = params[:key]

    # Start with user's projects and files
    @projects = current_user.projects
    @files = current_user.project_files.visible

    # Apply text search if query present
    if @query.present?
      @projects = @projects.where("LOWER(title) LIKE ?", "%#{@query.downcase}%")
      @files = @files.where("LOWER(original_filename) LIKE ?", "%#{@query.downcase}%")
    end

    # Apply date range filter
    if @date_from.present?
      date_from = Date.parse(@date_from) rescue nil
      if date_from
        @projects = @projects.where("created_at >= ?", date_from.beginning_of_day)
        @files = @files.where("created_at >= ?", date_from.beginning_of_day)
      end
    end

    if @date_to.present?
      date_to = Date.parse(@date_to) rescue nil
      if date_to
        @projects = @projects.where("created_at <= ?", date_to.end_of_day)
        @files = @files.where("created_at <= ?", date_to.end_of_day)
      end
    end

    # Apply BPM filter (extracted from filename)
    if @bpm_min.present? || @bpm_max.present?
      @files = filter_by_bpm(@files, @bpm_min, @bpm_max)
      @projects = filter_projects_by_bpm(@projects, @bpm_min, @bpm_max)
    end

    # Apply key filter (extracted from filename)
    if @key.present?
      @files = filter_by_key(@files, @key)
      @projects = filter_projects_by_key(@projects, @key)
    end

    # Apply sorting
    case @sort
    when 'recent'
      @projects = @projects.order(created_at: :desc)
      @files = @files.order(created_at: :desc)
    when 'oldest'
      @projects = @projects.order(created_at: :asc)
      @files = @files.order(created_at: :asc)
    when 'a-z'
      @projects = @projects.order(Arel.sql("LOWER(title) ASC"))
      @files = @files.order(Arel.sql("LOWER(original_filename) ASC"))
    when 'z-a'
      @projects = @projects.order(Arel.sql("LOWER(title) DESC"))
      @files = @files.order(Arel.sql("LOWER(original_filename) DESC"))
    else
      @projects = @projects.order(created_at: :desc)
      @files = @files.order(created_at: :desc)
    end

    # Limit results
    @projects = @projects.limit(50)
    @files = @files.limit(100)
  end

  # Autocomplete endpoint for search suggestions
  def suggestions
    query = params[:q].to_s.strip.downcase
    return render json: [] if query.length < 2

    # Get matching project titles
    projects = current_user.projects
      .where("LOWER(title) LIKE ?", "%#{query}%")
      .limit(5)
      .pluck(:title)

    # Get matching file names
    files = current_user.project_files.visible
      .where("LOWER(original_filename) LIKE ?", "%#{query}%")
      .limit(5)
      .pluck(:original_filename)

    # Combine and dedupe
    suggestions = (projects + files).uniq.first(8)

    render json: suggestions
  end

  private

  # Extract BPM from filename using regex
  # Matches patterns like: "74bpm", "74 bpm", "74BPM", "BPM 74", etc.
  def extract_bpm(filename)
    # Try various BPM patterns
    patterns = [
      /(\d{2,3})\s*bpm/i,      # 74bpm, 74 bpm, 74BPM
      /bpm\s*(\d{2,3})/i,      # bpm74, BPM 74
      /(\d{2,3})\s*tempo/i,    # 74tempo
      /_(\d{2,3})_/,           # _74_ (common separator pattern)
    ]

    patterns.each do |pattern|
      match = filename.match(pattern)
      return match[1].to_i if match
    end

    nil
  end

  # Extract musical key from filename
  # Matches patterns like: "Am", "A Minor", "Abm", "C#maj", "F# Minor", etc.
  def extract_key(filename)
    # Note: order matters - check sharps/flats before naturals
    notes = %w[Ab A# Bb B Cb C# Db D# Eb E Fb F# Gb G# A B C D E F G]
    modes = {
      'maj' => 'Major',
      'major' => 'Major',
      'min' => 'Minor',
      'minor' => 'Minor',
      'm' => 'Minor'
    }

    # Pattern: Note + optional mode
    # e.g., "Am", "A Minor", "C#maj", "Db minor"
    pattern = /(#{notes.join('|')})\s*(#{modes.keys.join('|')}|(?=[\s_\-\.]|$))/i

    match = filename.match(pattern)
    return nil unless match

    note = match[1]
    mode_abbrev = match[2].to_s.downcase

    # Determine if minor or major
    if mode_abbrev == 'm' || modes[mode_abbrev] == 'Minor'
      "#{note}m"
    elsif modes[mode_abbrev] == 'Major'
      "#{note}"
    else
      # If just the note, assume major for uppercase, minor for lowercase 'm' suffix
      note
    end
  end

  def filter_by_bpm(files, min_bpm, max_bpm)
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

  def filter_projects_by_bpm(projects, min_bpm, max_bpm)
    min_bpm = min_bpm.to_i if min_bpm.present?
    max_bpm = max_bpm.to_i if max_bpm.present?

    projects.select do |project|
      bpm = extract_bpm(project.title)
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

  def filter_projects_by_key(projects, key)
    key_normalized = normalize_key(key)
    return projects if key_normalized.nil?

    projects.select do |project|
      extracted = extract_key(project.title)
      next false unless extracted
      normalize_key(extracted) == key_normalized
    end
  end

  # Normalize key for comparison (e.g., "A minor" -> "Am", "C# Major" -> "C#")
  def normalize_key(key)
    return nil if key.blank?

    key = key.to_s.strip
    # Check for minor indicators
    if key.match?(/min|minor/i) || key.match?(/[A-G][#b]?m$/i)
      note = key.gsub(/\s*(min|minor|m).*$/i, '').strip
      "#{note}m"
    else
      key.gsub(/\s*(maj|major).*$/i, '').strip
    end
  end
end
