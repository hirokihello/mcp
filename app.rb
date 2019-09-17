# frozen_string_literal: true
require 'sinatra'
require 'docker'
require 'sinatra/reloader'
require 'pry-byebug'
require 'faraday'
require 'faraday_middleware'
require 'json'

set :server_settings, :timeout => 300

get '/' do

  create_image

  app = create_app_container
  db = create_db_container

  connect_network

  app.start
  db.start
  # どっかに閉じ込めたい
  puts app.exec(['apt', 'update'])
  puts app.exec(['apt', 'upgrade', '-qq', '-y'])
  puts app.exec(['apt', 'install', '-qq', '-y','nodejs', 'default-mysql-client', 'git', 'dnsutils'])

  puts app.exec(['git', 'clone', 'https://github.com/hirokihello/rails-docker-sample.git'])

  dir = "rails-docker-sample"
  puts app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle install"])
  puts app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle exec rails db:create"])
  puts app.exec(['mysql', '-u', 'root', '-h', 'ci_db_container'])
  puts app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle exec rails db:drop db:create"])

  # 標準出力先を指定
  $stdout = StringIO.new

  app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle exec rubocop"])
  # puts app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle exec rails db:fixtures"])
  # カレントディレクトリに全部コピーするのはファイル名被ったらやばいから脆弱性になるおわおわた

  # 出力された値を取得
  result = $stdout.string

  # 出力先を戻す
  $stdout = STDOUT

  app.stop
  db.stop
  app.remove
  db.remove
  result = "hoge"
  post_result_to_slack(result)
  result
end

private
  def create_image
    app_image = Docker::Image.create('fromImage' => 'ruby:2.6.3')
    app_image.tag('repo' => 'ruby-base-hirokihello', 'tag' => 'latest', force: true)

    db_image = Docker::Image.create('fromImage' => 'mysql:5.6')
    db_image.tag('repo' => 'mysql-base-hirokihello', 'tag' => 'latest', force: true)
  end

  def connect_network
    network = Docker::Network.get('ci-network')
    network = Docker::Network.create('ci-network') unless network
    network.connect('ci_app_container')
    network.connect('ci_db_container')
  end

  def create_app_container
    Docker::Container.create(
      'Cmd' => ['/bin/bash'],
      'Image' => 'ruby-base-hirokihello:latest',
      'OpenStdin' => true,
      'OpenStdout' => true,
      'tty' => true,
      'logs' => true,
      'name' => 'ci_app_container',
      'Env' => [
        'RAILS_ENV=test',
        'TEST_DATABASE_NAME=test_db',
        'TEST_DATABASE_USERNAME=sample',
        'TEST_DATABASE_PASSWORD=password',
        'TEST_DATABASE_HOST=ci_db_container',
        'TEST_DATABASE_PORT=3306',
      ]
    )
  end

  def create_db_container
    Docker::Container.create(
      'Image' => 'mysql-base-hirokihello:latest',
      'OpenStdin' => true,
      'OpenStdout' => true,
      'tty' => true,
      'logs' => true,
      'name' => 'ci_db_container',
      'Env' => [
        'MYSQL_ROOT_PASSWORD=password',
        'MYSQL_DATABASE=test_db',
        'MYSQL_HOST=172.*.*.*',
        'MYSQL_USER=sample',
        'MYSQL_PASSWORD=password',
      ]
    )
  end

  def post_result_to_slack(result)
    url = 'https://slack.com/api/chat.postMessage'

    conn = Faraday.new(:url => url) do |builder|
      builder.request :url_encoded
      builder.adapter Faraday.default_adapter
    end

    body ={
      token: ENV['SLACK_API_TOKEN'],
      channel: 'x-times-inoue_h',
      text: result
    }

    res = conn.post {|c| c.body = body}

  end