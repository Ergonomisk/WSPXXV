# frozen_string_literal: true

require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require_relative 'model'

enable :sessions
set :session_secret, 'rollspelsdax_super_hemlig_nyckel_som_ar_tillrackligt_lang_for_rack_session_kryptering'

# ────────────────────────────────────────
# Helpers (Vy-hjälpmetoder)
# ────────────────────────────────────────
helpers do
  # Kontrollerar om en användare är inloggad via sessionen.
  #
  # @return [Boolean] true om user_id finns i sessionen, annars false
  def logged_in?
    !session[:user_id].nil?
  end

  # Kräver att användaren är inloggad, annars omdirigeras till startsidan.
  #
  # @return [void]
  def require_login!
    redirect '/' unless logged_in?
  end

  # Hämtar den aktiva spelomgången för den inloggade spelaren och ett givet äventyr.
  # Skapar ett sessionstoken om inget finns sedan tidigare.
  #
  # @param adventure_id [Integer] id för äventyret
  # @return [Hash, nil] aktiv spelomgång som hash, eller nil om ingen pågår
  def current_run(adventure_id)
    token = session[:token] ||= SecureRandom.hex(16)
    PlayerRun.find_active(token, adventure_id)
  end

  # Startar en ny spelomgång för spelaren i ett givet äventyr,
  # med start i det första rummet.
  #
  # @param adventure_id [Integer] id för äventyret som ska startas
  # @return [Hash] den nyskapade spelomgångens data
  def start_run(adventure_id)
    token      = session[:token] ||= SecureRandom.hex(16)
    first_room = Room.first_in_adventure(adventure_id)
    PlayerRun.create(token, adventure_id, first_room['id'])
  end

  # Omvandlar spelarens kommaseparerade inventory-sträng till en array av föremålsnycklar.
  #
  # @param run [Hash] spelomgångens data-hash
  # @return [Array<String>] lista med föremålsnycklar, tom array om inventory saknas
  def inventory_list(run)
    return [] if run['inventory'].nil? || run['inventory'].empty?
    run['inventory'].split(',').map(&:strip).reject(&:empty?)
  end

  # Kontrollerar om spelaren bär på ett specifikt föremål i sin inventory.
  #
  # @param run [Hash] spelomgångens data-hash
  # @param item [String] föremålsnyckeln att leta efter
  # @return [Boolean] true om föremålet finns i inventory, annars false
  def has_item?(run, item)
    return false if item.nil? || item.empty?
    inventory_list(run).include?(item)
  end

  # Lägger till ett eller flera föremål i spelarens inventory.
  # Föremål anges som en kommaseparerad sträng.
  #
  # @param run [Hash] spelomgångens data-hash
  # @param items_str [String] kommaseparerad sträng med föremålsnycklar att lägga till
  # @return [void]
  def add_items(run, items_str)
    return if items_str.nil? || items_str.empty?
    inv = inventory_list(run)
    items_str.split(',').map(&:strip).each { |i| inv << i unless i.empty? }
    PlayerRun.update_inventory(run['id'], inv.join(','))
  end

  # Tar bort ett föremål från spelarens inventory.
  # Endast den första förekomsten av föremålet tas bort.
  #
  # @param run [Hash] spelomgångens data-hash
  # @param item [String] föremålsnyckeln att ta bort
  # @return [void]
  def remove_item(run, item)
    return if item.nil? || item.empty?
    inv = inventory_list(run)
    inv.delete_at(inv.index(item)) if inv.include?(item)
    PlayerRun.update_inventory(run['id'], inv.join(','))
  end

  # Returnerar ett läsbart namn med emoji för ett föremål baserat på dess nyckel.
  # Om nyckeln inte känns igen returneras nyckeln oförändrad.
  #
  # @param key [String] föremålsnyckeln, t.ex. 'sword' eller 'health_potion'
  # @return [String] föremålets visningsnamn med emoji, eller nyckeln om den saknas i listan
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
# Inloggning / Registrering
# ────────────────────────────────────────

# Lägger till en kort fördröjning på routen '/' för att motverka brute-force-attacker.
before('/') { sleep(0.5) }

# Visar inloggnings- och registreringssidan.
get '/' do
  slim :loggin
end

# Hanterar inloggningsformuläret. Autentiserar användaren och skapar en session.
# Omdirigerar till startsidan vid lyckad inloggning, annars tillbaka till '/' med felmeddelande.
post '/login' do
  user = User.authenticate(params['name'], params['pwd'])
  if user.nil?
    redirect('/?error=Fel+användarnamn+eller+lösenord')
  else
    session[:user_id] = user['id']
    redirect('/home')
  end
end

# Hanterar registreringsformuläret. Validerar indata och skapar en ny användare.
# Omdirigerar till startsidan vid lyckat skapande, annars tillbaka med felmeddelande.
post '/user' do
  name        = params['name']
  pwd         = params['pwd']
  pwd_confirm = params['pwd_confirm']

  if pwd.length < 3
    redirect('/?error=Lösenordet+måste+vara+minst+3+tecken')
  elsif pwd != pwd_confirm
    redirect('/?error=Lösenorden+matchar+inte')
  elsif User.exists?(name)
    redirect('/?error=Användarnamnet+är+redan+taget')
  else
    User.create(name, pwd)
    redirect('/home')
  end
end

# Loggar ut användaren genom att rensa sessionen och omdirigera till startsidan.
get '/logout' do
  session.clear
  redirect '/'
end

# ────────────────────────────────────────
# Hem: lista alla äventyr
# ────────────────────────────────────────

# Visar startsidan med en lista över alla tillgängliga äventyr.
# Stöder fritextsökning via query-parametern 'q'.
# Kräver att användaren är inloggad.
get '/home' do
  require_login!
  q = params[:q]
  @adventures = (q && !q.empty?) ? Adventure.search(q) : Adventure.all
  slim :index
end

# ────────────────────────────────────────
# Äventyrssidan: aktuellt rum, inventory, logg
# ────────────────────────────────────────

# Visar äventyrssidan med aktuellt rum, tillgängliga handlingar, inventory och logg.
# Om spelaren inte har en aktiv omgång visas en startsida istället.
# Returnerar 404 om äventyret inte finns.
# Kräver att användaren är inloggad.
get '/adventure/:id' do
  require_login!
  @adventure = Adventure.find(params[:id])
  halt 404, "Äventyret hittades inte" unless @adventure

  @run = current_run(@adventure['id'])

  if @run.nil?
    slim :adventure_start
  else
    @room        = Room.find(@run['current_room_id'])
    @total_rooms = Room.count_in_adventure(@adventure['id'])

    all_actions = Action.for_room(@room['id'])
    used_ids    = RunLog.used_action_ids(@run['id'])

    @available_actions = all_actions.select do |action|
      next false if used_ids.include?(action['id'])
      action['requires_item'].nil? || action['requires_item'].empty? || has_item?(@run, action['requires_item'])
    end

    @inventory = inventory_list(@run)
    @log       = RunLog.recent(@run['id'])

    slim :adventure
  end
end

# ────────────────────────────────────────
# Starta / starta om en spelomgång
# ────────────────────────────────────────

# Raderar eventuell befintlig omgång och startar en ny från början.
# Kräver att användaren är inloggad.
post '/adventure/:id/start' do
  require_login!
  adventure_id = params[:id].to_i
  token = session[:token] ||= SecureRandom.hex(16)
  PlayerRun.delete_for(token, adventure_id)
  start_run(adventure_id)
  redirect "/adventure/#{adventure_id}"
end

# ────────────────────────────────────────
# Utför en handling
# ────────────────────────────────────────

# Utför en vald handling i det aktuella rummet.
# Hanterar inventory-förändringar, loggning och eventuell rumsförflyttning eller avslut.
# Returnerar 400 om ingen aktiv omgång finns, handlingen är i fel rum,
# eller spelaren saknar ett krävt föremål. Returnerar 404 om handlingen inte finns.
# Kräver att användaren är inloggad.
post '/adventure/:id/action/:action_id' do
  require_login!
  adventure_id = params[:id].to_i
  action_id    = params[:action_id].to_i

  @run = current_run(adventure_id)
  halt 400, "Inget aktivt spel" unless @run

  action = Action.find(action_id)
  halt 404, "Handlingen hittades inte" unless action
  halt 400, "Fel rum"                  unless action['room_id'] == @run['current_room_id']

  if action['requires_item'] && !action['requires_item'].empty?
    halt 400, "Du har inte föremålet" unless has_item?(@run, action['requires_item'])
  end

  add_items(@run, action['gives_item'])     if action['gives_item']     && !action['gives_item'].empty?
  @run = PlayerRun.find(@run['id'])
  remove_item(@run, action['removes_item']) if action['removes_item']   && !action['removes_item'].empty?
  @run = PlayerRun.find(@run['id'])

  RunLog.create(@run['id'], action['id'], action['name'], action['result'])

  if action['moves_to_next'] == 1
    current_room = Room.find(@run['current_room_id'])
    next_room    = Room.next_room(adventure_id, current_room['room_order'])

    if next_room
      PlayerRun.move_to_room(@run['id'], next_room['id'])
    else
      PlayerRun.finish(@run['id'])
    end
  end

  session[:last_result] = action['result']
  redirect "/adventure/#{adventure_id}"
end