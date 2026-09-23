require 'bundler/setup'
Bundler.require
require 'uri'
require 'json'
require 'cgi'
require 'open3'

begin
  ActiveRecord::Base.establish_connection
  ActiveRecord::Base.connection.execute('SELECT 1')
rescue StandardError
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/development.sqlite3')
end
ActiveRecord::MigrationContext.new('db/migrate').migrate if ActiveRecord::Base.connection.adapter_name == 'SQLite'

class User < ActiveRecord::Base
  self.table_name = 'user'
  self.primary_key = 'user_id'

  has_secure_password
  validates :user_name, presence: true, uniqueness: { case_sensitive: false }

  has_many :references, foreign_key: 'reference_user_id', dependent: :destroy
  has_many :boards, foreign_key: 'board_user_id', dependent: :destroy
  has_many :reference_shares, foreign_key: 'share_user_id', dependent: :destroy
  has_many :board_shares, foreign_key: 'share_user_id', dependent: :destroy
end

class Reference < ActiveRecord::Base
  self.table_name = 'reference'
  self.primary_key = 'reference_id'

  belongs_to :user, foreign_key: 'reference_user_id'
  has_many :board_relates, class_name: 'BoardRelate', foreign_key: 'relate_board_reference_id', dependent: :destroy
  has_many :reference_shares, foreign_key: 'share_reference_id', dependent: :destroy
  validates :reference_url, presence: true

  def self.youtube_id(url)
    uri = URI.parse(url.to_s)
    host = uri.host.to_s.downcase.delete_prefix('www.')
    return uri.path.split('/')[1] if host == 'youtu.be'
    return unless %w[youtube.com m.youtube.com music.youtube.com].include?(host)
    return uri.path.split('/')[2] if uri.path.match?(%r{\A/(shorts|live|embed)/})
    Rack::Utils.parse_query(uri.query.to_s)['v'] if uri.path == '/watch'
  rescue StandardError
    nil
  end

  # 公開ページの画像を取得する。非公開・取得制限のある投稿は画像なしで保存できる。
  def self.thumbnail_for(url)
    return url if url.to_s.match?(%r{\A/uploads/[\w.-]+\z})

    uri = URI.parse(url.to_s)
    return unless uri.scheme == 'https' && uri.host

    host = uri.host.downcase.delete_prefix('www.')
    return url if uri.path.match?(/\.(?:jpe?g|png|gif|webp|avif)\z/i) || host == 'images.unsplash.com'

    id = youtube_id(url)
    return "https://img.youtube.com/vi/#{id}/hqdefault.jpg" if id.to_s.match?(/\A[\w-]{11}\z/)

    if %w[vimeo.com player.vimeo.com].include?(host)
      endpoint = "https://vimeo.com/api/oembed.json?url=#{URI.encode_www_form_component(url)}"
      image = JSON.parse(fetch_public(endpoint).to_s)['thumbnail_url'] rescue nil
      image = decode_html(image)
      return image if image.to_s.start_with?('https://')
    end

    return unless %w[vimeo.com player.vimeo.com instagram.com x.com twitter.com].include?(host)

    tag = fetch_public(url).to_s.scan(/<meta\b[^>]*>/i).find do |meta|
      meta.match?(/(?:property|name)=["'](?:og:image|twitter:image)["']/i)
    end
    image = decode_html(tag.to_s[/\bcontent=["']([^"']+)/i, 1].to_s)
    image if image.start_with?('https://')
  rescue StandardError
    nil
  end

  def self.fetch_public(url)
    body, _error, status = Open3.capture3('curl', '-fsS', '--connect-timeout', '3', '--max-time', '6',
                                          '--max-filesize', '1200000', '--proto', '=https', '--', url)
    body if status.success?
  end

  def self.decode_html(value)
    2.times { value = CGI.unescapeHTML(value.to_s) }
    value
  end
  private_class_method :fetch_public, :decode_html

  def image_url
    return reference_imageurl if reference_imageurl.present?
    id = Reference.youtube_id(reference_url)
    id.to_s.match?(/\A[\w-]{11}\z/) ? "https://img.youtube.com/vi/#{id}/hqdefault.jpg" : ''
  end
end

class Board < ActiveRecord::Base
  self.table_name = 'board'
  self.primary_key = 'board_id'

  validates :board_name, presence: true

  belongs_to :user, foreign_key: 'board_user_id'
  has_many :board_relates, -> { order(:relate_board_position) }, class_name: 'BoardRelate', foreign_key: 'relate_board_id', dependent: :destroy
  has_many :board_shares, foreign_key: 'share_board_id', dependent: :destroy
  has_many :slides, -> { order(:position) }, class_name: 'BoardSlide', foreign_key: 'board_id', dependent: :destroy
end

class BoardSlide < ActiveRecord::Base
  belongs_to :board, foreign_key: 'board_id'

  def data
    JSON.parse(content.to_s)
  rescue JSON::ParserError
    { 'refs' => [], 'notes' => [], 'strokes' => [] }
  end
end

class BoardRelate < ActiveRecord::Base
  self.table_name = 'boardrelate'
  self.primary_key = 'boardrelate_id'

  belongs_to :board, foreign_key: 'relate_board_id'
  belongs_to :reference, foreign_key: 'relate_board_reference_id'

  alias_attribute :relate_board_text, :ralate_borad_text
end

class ReferenceShare < ActiveRecord::Base
  self.table_name = 'reference_share'
  self.primary_key = 'reference_share_id'

  belongs_to :reference, foreign_key: 'share_reference_id'
  belongs_to :user, foreign_key: 'share_user_id'
end

class BoardShare < ActiveRecord::Base
  self.table_name = 'board_share'
  self.primary_key = 'board_share_id'

  belongs_to :board, foreign_key: 'share_board_id'
  belongs_to :user, foreign_key: 'share_user_id'
end
