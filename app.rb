# frozen_string_literal: true
require 'sinatra'
require 'docker'
require 'sinatra/reloader'
require 'pry-byebug'

set :server_settings, :timeout => 300

get '/' do
  network = Docker::Network.get('ci-network')
  network = Docker::Network.create('ci-network') unless network


  db_image = Docker::Image.create('fromImage' => 'mysql:5.6')
  db_image.tag('repo' => 'mysql-base-hirokihello', 'tag' => 'latest', force: true)

  app = Docker::Container.create(
    'Cmd' => ['/bin/bash'],
    'Image' => 'ruby-base-hirokihello:latest',
    'OpenStdin' => true,
    'OpenStdout' => true,
    'tty' => true,
    'logs' => true,
    'name' => 'ci_app_container',
    'net' => 'ci-network',
    'Env' => [
      'TEST_DATABASE_NAME=testdb',
      'TEST_DATABASE_USERNAME=hirokihello',
      'TEST_DATABASE_PASSWORD=password',
      'TEST_DATABASE_HOST=ci_db_container',
      'TEST_DATABASE_PORT=3306',
    ]
  )

  db = Docker::Container.create(
    'Cmd' => ["/bin/bash"],
    'Image' => 'mysql-base-hirokihello:latest',
    'OpenStdin' => true,
    'OpenStdout' => true,
    'tty' => true,
    'logs' => true,
    'name' => 'ci_db_container',
    'net' => 'ci-network',
    'Env' => [
      'MYSQL_ROOT_PASSWORD=password',
      'MYSQL_USER=hirokihello'
    ]
  )

  network.connect('ci_app_container')
  network.connect('ci_db_container')
  app.start
  db.start

  puts app.exec(['apt', 'update'])
  puts "upgradeを走らせる"
  puts app.exec(['apt', 'upgrade', '-qq', '-y'])
  puts app.exec(['apt', 'install', 'git'])
  puts app.exec(['apt', 'install', 'dnsutils', '-qq', '-y'])
  puts "nslookupをうつ"
  puts app.exec(['dig', 'ci_db_container'])

  puts app.exec(['bundler', '-v'])
  puts  "git clone"
  puts app.exec(['git', 'clone', 'https://github.com/hirokihello/rails-realworld-example-app.git'])

  puts  "cd | ls"
  dir = "rails-realworld-example-app"
  puts app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle install"])
  puts app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle exec rails db:drop db:create RAILS_ENV=test"])
  puts app.exec(['/bin/bash', '-c', "cd ./#{dir} && bundle exec rails db:fixtures"])
# カレントディレクトリに全部コピーするのはファイル名被ったらやばいから脆弱性になるおわおわた

  puts app.exec(['ls', '-l'])
binding.pry
  command = ["/bin/bash", "-c", "echo -n \"I'm a TTY!\""]
  puts app.exec(command, tty: true)
  app.stop
  db.stop
  app.remove
  db.remove
  "hello"
end

private

  def create_app_container
  end