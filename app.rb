require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require './models'
require 'securerandom'
require 'uri'
require 'json'
require 'fileutils'

enable :sessions
use Rack::MethodOverride

set :public_folder, File.join(__dir__, 'public')
FileUtils.mkdir_p(File.join(__dir__, 'public/uploads'))

helpers do
  def current_user
    @current_user ||= User.find_by(user_id: session[:user_id])
  end

  def can_view_board?(board)
    return false if board.nil?
    return true if current_user && board.board_user_id == current_user.user_id
    return true if board.board_is_public
    return true if current_user && BoardShare.exists?(share_board_id: board.board_id, share_user_id: current_user.user_id)
    false
  end

  def h(val)
    Rack::Utils.escape_html(val.to_s)
  end

  def reference_provider(url)
    host = URI.parse(url.to_s).host.to_s.downcase.delete_prefix('www.')
    return :youtube if %w[youtu.be youtube.com m.youtube.com music.youtube.com].include?(host)
    return :vimeo if %w[vimeo.com player.vimeo.com].include?(host)
    return :x if %w[x.com twitter.com].include?(host)
    return :instagram if host == 'instagram.com'
    :web
  rescue URI::InvalidURIError
    :web
  end

  def provider_name(p)
    { youtube: 'YouTube', vimeo: 'Vimeo', x: 'X', instagram: 'Instagram', web: 'Web' }[p]
  end

  def provider_icon(p)
    { youtube: 'fab fa-youtube', vimeo: 'fab fa-vimeo-v', x: 'fab fa-x-twitter', instagram: 'fab fa-instagram', web: 'fas fa-globe' }[p]
  end

  def time_seconds(str)
    return str.to_i if str.to_s.match?(/\A\d+\z/)
    parts = str.to_s.split(':').map(&:to_i)
    parts.reverse.each_with_index.sum { |n, i| n * (60**i) } if [2, 3].include?(parts.length)
  end

  def image_for(url)
    Reference.thumbnail_for(url)
  end

  def source_url(url)
    return url if url.to_s.match?(%r{\A/uploads/[\w.-]+\z})
    uri = URI.parse(url.to_s)
    url if %w[http https].include?(uri.scheme) && uri.host
  rescue URI::InvalidURIError
    nil
  end

  def video_embed_url(ref)
    url = ref.reference_url
    if reference_provider(url) == :youtube && (id = Reference.youtube_id(url)) && id.match?(/\A[\w-]{11}\z/)
      start = time_seconds(ref.reference_start_time)
      finish = time_seconds(ref.reference_end_time)
      q = { playsinline: 1, rel: 0 }
      q[:start] = start if start && start > 0
      q[:end] = finish if finish && finish > (start || 0)
      "https://www.youtube.com/embed/#{id}?#{URI.encode_www_form(q)}"
    elsif reference_provider(url) == :vimeo && (id = url.to_s.match(%r{vimeo\.com/(?:video/)?(\d+)})&.captures&.first)
      start = time_seconds(ref.reference_start_time)
      "https://player.vimeo.com/video/#{id}?dnt=1#{start && start > 0 ? "#t=#{start}s" : ''}"
    end
  rescue StandardError
    nil
  end

  def save_upload(file)
    return unless file && file[:tempfile] && file[:filename].to_s.present?
    ext = File.extname(file[:filename]).downcase
    ext = '.png' unless %w[.jpg .jpeg .png .gif .webp].include?(ext)
    name = "#{SecureRandom.hex(10)}#{ext}"
    File.binwrite(File.join(settings.public_folder, 'uploads', name), file[:tempfile].read)
    "/uploads/#{name}"
  end

  def add_to_board(board, ref, note = '', slide = nil)
    return unless board && ref

    rel = BoardRelate.find_or_initialize_by(relate_board_id: board.board_id, relate_board_reference_id: ref.reference_id)
    rel.relate_board_text = note.to_s if note.present?
    rel.relate_board_position ||= (board.board_relates.maximum(:relate_board_position) || 0) + 1
    rel.save if rel.changed? || rel.new_record?

    slide ||= board.slides.first || board.slides.create!(position: 1)
    data = slide.data
    coords = [[15, 18], [55, 18], [15, 52], [55, 52]][(data['refs'] || []).length % 4]
    data['refs'] = (data['refs'] || []) << { 'id' => ref.reference_id, 'x' => coords[0], 'y' => coords[1], 'w' => 30 }
    data['notes'] = (data['notes'] || []) << { 'id' => SecureRandom.hex(4), 'text' => note.to_s[0, 500], 'x' => 60, 'y' => 55, 'w' => 28 } if note.present?
    slide.update!(content: JSON.generate(data))
  end
end


get '/' do
  if current_user
    @title = 'ホーム | RefBOX'
    @boards = current_user.boards.order(timestamp: :desc)
    @selected_board_id = params[:board_id].to_s.strip
    if @selected_board_id.present? && (board = current_user.boards.find_by(board_id: @selected_board_id))
      @items = board.board_relates.includes(:reference).map(&:reference).compact
    else
      @items = current_user.references.order(timestamp: :desc)
    end
    erb :index
  else
    @title = 'RefBOX - リファレンスマネジメント'
    erb :welcome
  end
end

get '/login' do
  redirect '/' if current_user
  @title = 'ログイン | RefBOX'
  erb :login
end

post '/login' do
  user = User.find_by('LOWER(user_name) = ?', params[:user_name].to_s.strip.downcase)
  if user && user.authenticate(params[:password])
    session[:user_id] = user.user_id
    redirect '/'
  else
    @title = 'ログイン | RefBOX'
    @error = 'ユーザー名またはパスワードが違います'
    erb :login
  end
end

get '/signup' do
  redirect '/' if current_user
  @title = '新規登録 | RefBOX'
  erb :signup
end

post '/signup' do
  user = User.create(
    user_name: params[:user_name].to_s.strip,
    password: params[:password],
    user_iconurl: ''
  )
  if user.persisted?
    session[:user_id] = user.user_id
    redirect '/'
  else
    @title = '新規登録 | RefBOX'
    @error = user.errors.full_messages.join('、')
    erb :signup
  end
end

get '/logout' do
  session.clear
  redirect '/login'
end

post '/logout' do
  session.clear
  redirect '/login'
end


get '/reference' do
  redirect '/login' unless current_user
  @title = 'リファレンスを追加 | RefBOX'
  erb :reference
end

post '/reference/preview' do
  redirect '/login' unless current_user

  uploaded = save_upload(params[:file])
  url = source_url(uploaded || params[:reference_url].to_s.strip)
  redirect '/reference' unless url

  @url = url
  @provider = reference_provider(url)
  @image_url = uploaded || image_for(url)
  @boards = current_user.boards.order(timestamp: :desc)

  if %i[youtube vimeo].include?(@provider)
    @title = "#{provider_name(@provider)}からインポート | RefBOX"
    @start_time = '00:00'
    @end_time = '00:30'
    erb :reference_youtube
  else
    @title = 'インポート確認 | RefBOX'
    if @provider == :x
      m = URI.parse(url).path.match(%r{\A/([\w]{1,15})/status/(\d+)}) rescue nil
      @username = m[1] if m
    end
    erb :reference_confirm
  end
end

post '/reference/preview/confirm' do
  redirect '/login' unless current_user

  @url = source_url(params[:reference_url].to_s.strip)
  redirect '/reference' unless @url
  @provider = reference_provider(@url)
  @image_url = params[:reference_imageurl].presence || image_for(@url)
  @start_time = params[:reference_start_time].to_s.strip
  @end_time = params[:reference_end_time].to_s.strip
  @boards = current_user.boards.order(timestamp: :desc)
  @title = 'インポート確認 | RefBOX'
  erb :reference_confirm
end

post '/reference' do
  redirect '/login' unless current_user

  uploaded = save_upload(params[:file])
  url = source_url(uploaded || params[:reference_url].to_s.strip)
  redirect '/reference' unless url

  ref = current_user.references.create(
    reference_url: url,
    reference_imageurl: uploaded || params[:reference_imageurl].presence || image_for(url),
    reference_text: params[:reference_text].to_s.strip[0, 255],
    reference_start_time: params[:reference_start_time].to_s.strip,
    reference_end_time: params[:reference_end_time].to_s.strip,
    timestamp: Time.now
  )

  if params[:board_id].present? && (board = current_user.boards.find_by(board_id: params[:board_id]))
    add_to_board(board, ref)
  end
  redirect '/'
end

post '/reference/:id' do
  redirect '/login' unless current_user

  ref = current_user.references.find_by(reference_id: params[:id])
  if ref
    attrs = { reference_text: params[:reference_text].to_s.strip[0, 255] }
    if params[:reference_start_time].present? || params[:reference_end_time].present?
      attrs[:reference_start_time] = params[:reference_start_time].to_s.strip
      attrs[:reference_end_time] = params[:reference_end_time].to_s.strip
    end
    ref.update(attrs)
  end
  redirect '/'
end

post '/reference/:id/delete' do
  redirect '/login' unless current_user
  current_user.references.find_by(reference_id: params[:id])&.destroy
  redirect '/'
end

delete '/reference/:id' do
  redirect '/login' unless current_user
  current_user.references.find_by(reference_id: params[:id])&.destroy
  redirect '/'
end

get '/board' do
  redirect '/login' unless current_user

  @title = 'あなたのボード | RefBOX'
  @boards = current_user.boards.order(timestamp: :desc)
  erb :boards
end

post '/board' do
  redirect '/login' unless current_user

  board = current_user.boards.create(
    board_name: params[:board_name].to_s.strip,
    board_is_public: params[:board_is_public] == '1',
    timestamp: Time.now
  )
  board.slides.create!(position: 1) if board.persisted?
  redirect board.persisted? ? "/board/#{board.board_id}" : '/board'
end

get '/board/:board_id' do
  board = Board.find_by(board_id: params[:board_id])
  unless can_view_board?(board)
    redirect current_user ? '/board' : '/login'
  end

  @board = board
  @title = "#{@board.board_name} | RefBOX"
  @is_owner = current_user && current_user.user_id == board.board_user_id
  @library = @is_owner ? current_user.references.order(timestamp: :desc) : []
  @slides = board.slides.to_a
  @slides << board.slides.create!(position: 1) if @slides.empty?
  @slide = @slides.find { |s| s.id == params[:slide_id].to_i } || @slides.first
  @slide_data = @slide.data
  ref_ids = Array(@slide_data['refs']).map { |r| r['id'].to_i } | @library.map(&:reference_id)
  @references_by_id = Reference.where(reference_id: ref_ids).index_by(&:reference_id)
  erb :workspace
end

post '/board/:board_id/reference' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  ref = current_user.references.find_by(reference_id: params[:reference_id])
  slide = board.slides.find_by(id: params[:slide_id]) if board
  add_to_board(board, ref, params[:relate_board_text], slide) if board && ref
  redirect board ? "/board/#{board.board_id}?slide_id=#{slide&.id || board.slides.first&.id}" : '/board'
end

post '/board/:board_id/slide' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  slide = board.slides.create!(position: board.slides.maximum(:position).to_i + 1) if board
  redirect slide ? "/board/#{board.board_id}?slide_id=#{slide.id}" : '/board'
end

post '/board/:board_id/slide/:slide_id' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  slide = board.slides.find_by(id: params[:slide_id]) if board
  halt 404 unless slide

  begin
    raw = request.body.read(250_000).to_s.force_encoding('UTF-8')
    JSON.parse(raw)
    slide.update!(content: raw)
    status 204
  rescue JSON::ParserError, ActiveRecord::ActiveRecordError => e
    warn "Slide save error: #{e.class} - #{e.message}"
    halt 400
  end
end

post '/board/:board_id/slide/:slide_id/delete' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  slide = board.slides.find_by(id: params[:slide_id]) if board
  if slide
    board.slides.count > 1 ? slide.destroy! : slide.update!(content: '{"refs":[],"notes":[],"strokes":[]}')
  end
  redirect board ? "/board/#{board.board_id}" : '/board'
end

post '/board/:board_id/reference/:id/delete' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  rel = board&.board_relates&.find_by(boardrelate_id: params[:id])
  rel&.destroy
  redirect board ? "/board/#{board.board_id}" : '/board'
end

delete '/board/:board_id/reference/:id' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  rel = board&.board_relates&.find_by(boardrelate_id: params[:id])
  rel&.destroy
  redirect board ? "/board/#{board.board_id}" : '/board'
end

post '/board/:board_id/toggle_public' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  halt 404 unless board

  board.update!(board_is_public: !board.board_is_public)

  if request.xhr? || request.content_type.to_s.include?('json') || request.env['HTTP_ACCEPT'].to_s.include?('application/json')
    content_type :json
    { is_public: board.board_is_public }.to_json
  else
    redirect "/board/#{board.board_id}"
  end
end

post '/board/:board_id/delete' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  board&.destroy
  redirect '/board'
end

delete '/board/:board_id' do
  redirect '/login' unless current_user

  board = current_user.boards.find_by(board_id: params[:board_id])
  board&.destroy
  redirect '/board'
end
