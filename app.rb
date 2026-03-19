require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions
set :session_secret, 'rollspelsdax_super_hemlig_nyckel_som_ar_tillrackligt_lang_for_rack_session_kryptering'

# ────────────────────────────────────────
# Helpers
# ────────────────────────────────────────
helpers do
  def db
    @db ||= begin
      database = SQLite3::Database.new('db/databas.db')
      database.results_as_hash = true
      database
    end
  end

  def logged_in?
    !session[:user_id].nil?
  end

  def require_login!
    redirect '/' unless logged_in?
  end

  def current_run(adventure_id)
    token = session[:token] ||= SecureRandom.hex(16)
    db.execute(
      "SELECT * FROM player_runs WHERE session_token = ? AND adventure_id = ? AND finished = 0",
      [token, adventure_id]
    ).first
  end

  def start_run(adventure_id)
    token = session[:token] ||= SecureRandom.hex(16)
    first_room = db.execute(
      "SELECT * FROM arooms WHERE adventure_id = ? ORDER BY room_order ASC LIMIT 1",
      adventure_id
    ).first
    db.execute(
      "INSERT INTO player_runs (session_token, adventure_id, current_room_id, inventory) VALUES (?, ?, ?, '')",
      [token, adventure_id, first_room['id']]
    )
    db.execute(
      "SELECT * FROM player_runs WHERE session_token = ? AND adventure_id = ? AND finished = 0",
      [token, adventure_id]
    ).first
  end

  def inventory_list(run)
    return [] if run['inventory'].nil? || run['inventory'].empty?
    run['inventory'].split(',').map(&:strip).reject(&:empty?)
  end

  def has_item?(run, item)
    return false if item.nil? || item.empty?
    inventory_list(run).include?(item)
  end

  def add_items(run, items_str)
    return if items_str.nil? || items_str.empty?
    inv = inventory_list(run)
    items_str.split(',').map(&:strip).each { |i| inv << i unless i.empty? }
    db.execute("UPDATE player_runs SET inventory = ? WHERE id = ?", [inv.join(','), run['id']])
  end

  def remove_item(run, item)
    return if item.nil? || item.empty?
    inv = inventory_list(run)
    inv.delete_at(inv.index(item)) if inv.include?(item)
    db.execute("UPDATE player_runs SET inventory = ? WHERE id = ?", [inv.join(','), run['id']])
  end

  def item_name(key)
    names = {
      'sword'        => '🗡️ Rostigt svärd',
      'health_potion'=> '🧪 Hälsodryck',
      'gold_coin'    => '🪙 Guldmynt',
      'key'          => '🗝️ Nyckel',
      'magic_sword'  => '✨ Magiskt svärd',
      'rusty_key'    => '🗝️ Rostig nyckel',
      'oil'          => '🫙 Olja',
      'castle_sword' => '⚔️ Slottssvärd',
      'wand'         => '🪄 Besvärjelsepinne',
      'shield_spell' => '🛡️ Skyddszauber',
      'victory'      => '🏆 Seger'
    }
    names[key] || key
  end
end

# ────────────────────────────────────────
# Login / Register
# ────────────────────────────────────────
get '/' do
  slim :loggin
end

post '/login' do
  name = params["name"]
  pwd  = params["pwd"]
  db2  = SQLite3::Database.new("db/databas.db")
  db2.results_as_hash = true
  result = db2.execute("SELECT id, pwd_digest FROM user WHERE name = ?", name)
  if result.empty?
    redirect('/?error=Användaren+finns+inte')
  end
  user_id    = result.first["id"]
  pwd_digest = result.first["pwd_digest"]
  if BCrypt::Password.new(pwd_digest) == pwd
    session[:user_id] = user_id
    redirect('/home')
  else
    redirect('/?error=Fel+lösenord')
  end
end

post '/user' do
  name        = params["name"]
  pwd         = params["pwd"]
  pwd_confirm = params["pwd_confirm"]

  if pwd.length < 3
    redirect('/?error=Lösenordet+måste+vara+minst+3+tecken')
  end

  db2    = SQLite3::Database.new("db/databas.db")
  result = db2.execute("SELECT id FROM user WHERE name = ?", name)

  if result.empty?
    if pwd == pwd_confirm
      pwd_digest = BCrypt::Password.create(pwd)
      db2.execute("INSERT INTO user (name, pwd_digest) VALUES (?, ?)", [name, pwd_digest])
      redirect('/home')
    else
      redirect('/?error=Lösenorden+matchar+inte')
    end
  else
    redirect('/?error=Användarnamnet+är+redan+taget')
  end
end

get '/logout' do
  session.clear
  redirect '/'
end

# ────────────────────────────────────────
# Home: list all adventures
# ────────────────────────────────────────
get '/home' do
  require_login!
  q = params[:q]
  if q && !q.empty?
    @adventures = db.execute("SELECT * FROM adventurename WHERE name LIKE ?", "%#{q}%")
  else
    @adventures = db.execute("SELECT * FROM adventurename")
  end
  slim :index
end

# ────────────────────────────────────────
# Adventure page: current room, inventory, log
# ────────────────────────────────────────
get '/adventure/:id' do
  require_login!
  @adventure = db.execute("SELECT * FROM adventurename WHERE id = ?", params[:id].to_i).first
  halt 404, "Äventyret hittades inte" unless @adventure

  @run = current_run(@adventure['id'])

  if @run.nil?
    slim :adventure_start
  else
    @room = db.execute("SELECT * FROM arooms WHERE id = ?", @run['current_room_id']).first
    @total_rooms = db.execute(
      "SELECT COUNT(*) as c FROM arooms WHERE adventure_id = ?", @adventure['id']
    ).first['c']

    all_actions = db.execute("SELECT * FROM actions WHERE room_id = ?", @room['id'])

  
    used_ids = db.execute(
      "SELECT action_id FROM run_log WHERE run_id = ?", @run['id']
    ).map { |row| row['action_id'] }

    @available_actions = all_actions.select do |action|
      next false if used_ids.include?(action['id'])  # redan använd
      action['requires_item'].nil? || action['requires_item'].empty? || has_item?(@run, action['requires_item'])
    end

    @inventory = inventory_list(@run)

    @log = db.execute(
      "SELECT * FROM run_log WHERE run_id = ? ORDER BY id DESC LIMIT 5",
      @run['id']
    )

    slim :adventure
  end
end

# ────────────────────────────────────────
# Start / restart a run
# ────────────────────────────────────────
post '/adventure/:id/start' do
  require_login!
  adventure_id = params[:id].to_i
  token = session[:token] ||= SecureRandom.hex(16)
  db.execute(
    "DELETE FROM player_runs WHERE session_token = ? AND adventure_id = ?",
    [token, adventure_id]
  )
  start_run(adventure_id)
  redirect "/adventure/#{adventure_id}"
end

# ────────────────────────────────────────
# Take an action
# ────────────────────────────────────────
post '/adventure/:id/action/:action_id' do
  require_login!
  adventure_id = params[:id].to_i
  action_id    = params[:action_id].to_i

  @run = current_run(adventure_id)
  halt 400, "Inget aktivt spel" unless @run

  action = db.execute("SELECT * FROM actions WHERE id = ?", action_id).first
  halt 404, "Handlingen hittades inte" unless action
  halt 400, "Fel rum" unless action['room_id'] == @run['current_room_id']

  if action['requires_item'] && !action['requires_item'].empty?
    halt 400, "Du har inte föremålet" unless has_item?(@run, action['requires_item'])
  end

  add_items(@run, action['gives_item']) if action['gives_item'] && !action['gives_item'].empty?
  @run = db.execute("SELECT * FROM player_runs WHERE id = ?", @run['id']).first
  remove_item(@run, action['removes_item']) if action['removes_item'] && !action['removes_item'].empty?
  @run = db.execute("SELECT * FROM player_runs WHERE id = ?", @run['id']).first

  db.execute(
  "INSERT INTO run_log (run_id, action_id, action_name, result_text) VALUES (?, ?, ?, ?)",
  [@run['id'], action['id'], action['name'], action['result']]
  )
  

  if action['moves_to_next'] == 1
    current_room = db.execute("SELECT * FROM arooms WHERE id = ?", @run['current_room_id']).first
    next_room = db.execute(
      "SELECT * FROM arooms WHERE adventure_id = ? AND room_order = ?",
      [adventure_id, current_room['room_order'] + 1]
    ).first

    if next_room
      db.execute(
        "UPDATE player_runs SET current_room_id = ? WHERE id = ?",
        [next_room['id'], @run['id']]
      )
    else
      db.execute("UPDATE player_runs SET finished = 1 WHERE id = ?", @run['id'])
    end
  end

  session[:last_result] = action['result']
  redirect "/adventure/#{adventure_id}"
end
