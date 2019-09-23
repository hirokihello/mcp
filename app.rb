# frozen_string_literal: true
require 'sinatra'
require 'docker'
require 'sinatra/reloader'
require 'pry-byebug'
require 'faraday'
require 'faraday_middleware'
require 'json'
require 'yaml'

set :server_settings, :timeout => 300

CONTAINER_NAMES = [
  "ci_app_container",
  "ci_container_1",
  "ci_container_2",
  "ci_container_3"
]

get '/' do
  @network = Docker::Network.get('ci-network') || Docker::Network.create('ci-network')
  @container_count = 0
  # スクレイピング先のURL
  url = 'https://raw.githubusercontent.com/hirokihello/rails-docker-sample/master/.circleci/config.yml'
  uri = URI(url)

  file = Net::HTTP.get(uri)
  File.open('config.yml', 'w') do |f|
    f.puts file
  end

  config = YAML.load_file("config.yml")

  return "hello" unless config["jobs"]["build"]["docker"]
  return "errro" unless config["jobs"]["build"]["docker"].any?

  create_container(config["jobs"]["build"]["docker"])

  return "hrllo" if @container_count == 0

  app = Docker::Container.get(CONTAINER_NAMES[0])

  puts app.exec(['git', 'clone', 'https://github.com/hirokihello/rails-docker-sample.git'])

  @dir = "rails-docker-sample"

  puts app.exec(['apt', 'update'])
  # puts app.exec(['apt', 'upgrade', '-qq', '-y'])
  puts app.exec(['apt', 'install', '-qq', '-y','nodejs', 'default-mysql-client', 'git', 'dnsutils', 'openssl'])

  # 標準出力先を指定
  $stdout = StringIO.new
  exec_commands(app, config["jobs"]["build"]["steps"])

  result = $stdout.string
  $stdout = STDOUT

  stop_container
  puts result.to_s

  # post_result_to_slack(result)
  result
end

private
  def create_container(container_info)
    container_info.each_with_index do |info, idx|
      env = info["environment"].map do |key, value|
        "#{key}=#{value}"
      end
      container = Docker::Container.create(
        'Image' => info["image"],
        'OpenStdin' => true,
        'OpenStdout' => true,
        'tty' => true,
        'logs' => true,
        'name' => CONTAINER_NAMES[idx],
        'Env' => env
      )
      @network.connect(CONTAINER_NAMES[idx])
      container.start
      @container_count += 1
    end
  end

  def exec_commands(container, commands)
    commands.each do |com|
      c = com["run"]
      next unless c
      puts container.exec(['/bin/bash', '-c', "cd ./#{@dir} && #{c["command"]}"])
    end
  end

  def stop_container
    @container_count.times do |n|
      cn = CONTAINER_NAMES[n]
      con = Docker::Container.get(cn)
      # これ取得できないとエラーが生じる。。。
      con.stop
      con.remove
    end
  end

  def post_result_to_slack(result)
    url = 'https://slack.com/api/chat.postMessage'

    conn = Faraday.new(:url => url) do |builder|
      builder.request :url_encoded
      builder.response :logger
      builder.adapter Faraday.default_adapter
    end


    body ={
      token: ENV['SLACK_API_TOKEN'],
      channel: 'x-times-inoue_h',
      text: "#{result}"
    }

    res = conn.post {|c| c.body = body}

  end