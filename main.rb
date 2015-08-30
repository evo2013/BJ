require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => '2jcuyte9lp'

BLACKJACK_AMOUNT = 21
DEALER_MIN = 17

helpers do
  def calculate_total(cards)
    arr = cards.map { |e| e[1] }

    total = 0
    arr.each do |value|
      if value == "A"
        total += 11
      else
        total += value.to_i == 0 ? 10 : value.to_i
      end
    end

    #correct for Aces
    arr.select{|e| e == "A"}.count.times do
      break if total <= BLACKJACK_AMOUNT
        total -= 10
      end
    total
  end

  def card_image(card) ['H', '3']
    suit = case card[0]
      when 'H' then 'hearts'
      when 'S' then 'spades'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
    end

    value = card[1]
    if ['J', 'Q', 'K', "A"].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src= '/images/cards/#{suit}_#{value}.gif' class = 'class_image' >"
  end
end

def winner(msg)
  @replay = true
  @show_hit_or_stay_buttons = false
  session[:bankroll] += session[:player_bet].to_i
  @winner = "Felicitations #{session[:player_name]}, vous avez gagne! #{msg}"
end

def dwinner(msg)
  @replay = true
  @show_hit_or_stay_buttons = false
  session[:bankroll] -= session[:player_bet].to_i
  @loser = "Desole #{session[:player_name]}! #{msg} "
end

def loser(msg)
  @replay = true
  @show_hit_or_stay_buttons = false
  session[:bankroll] -= session[:player_bet].to_i
  @loser = "Desole #{session[:player_name]}, vous perdez! #{msg}"
end

def tie(msg)
  @replay = true
  @show_hit_or_stay_buttons = false
  @winner = "C'est une cravate! Aucun vainqueur."
end

get '/demo' do
  erb :demo
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do 
  if session[:player_name]
    redirect '/game'
  else
    redirect '/set_name'
  end
end

get '/set_name' do
  erb :set_name
end

post '/set_name' do
  if params[:player_name].empty? 
    @error = "Le nom est necessaire."
    halt erb(:set_name)
  elsif params[:bet].nil? || params[:bet].to_i <= 0 
    @error = "Le montant de la mise est requis et doit etre un nombre superieur a zero."
    halt erb(:set_name)
  elsif params[:bankroll].nil? || params[:bankroll].to_i <= 0 
    @error = "Total bankroll est requis et doit etre un nombre superieur a 0. "
    halt erb(:set_name)
  elsif params[:bet].to_i > params[:bankroll].to_i
    @error = "Montant de la mise ne peut pas etre superieure a votre disponible."
    halt erb(:set_name)
  else 
    session[:player_name] = params[:player_name]
    session[:player_bet] = params[:bet].to_i.round
    session[:bankroll] = params[:bankroll].to_i.round
    # session[:player_total] = params[:player_total]
    redirect '/game'
  end
end

get '/bet' do
  session[:player_bet] = nil
  erb :bet
end

post '/bet' do
  if params[:bet].nil? || params[:bet].to_i == 0
    @error = "Montant doit etre superieure a 0."
    halt erb(:bet)
  elsif params[:bet].to_i > session[:bankroll]
    @error = "Montant de la mise ne peut pas etre superieure a votre bankroll de #{session[:bankroll]} Euro."
    halt erb(:bet)
  else
    session[:player_bet] = params[:bet].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  session[:dealer_cards] = []
  session[:player_cards] = []
  2.times do 
     session[:dealer_cards] << session[:deck].pop
     session[:player_cards] << session[:deck].pop
  end

  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])
  if player_total == BLACKJACK_AMOUNT
    @replay = true
    winner("Vous venez de hit BlackJack.")
    @show_hit_or_stay_buttons = false
  elsif dealer_total == BLACKJACK_AMOUNT
    @replay = true
    dwinner("Concessionnaire vient frapper Blackjack.")
    @show_hit_or_stay_buttons = false
  end

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK_AMOUNT
    winner("Vous venez de hit BlackJack.")
  elsif player_total > BLACKJACK_AMOUNT
    loser("Vous venez de busted a #{player_total}.")
  end

  erb :game
end

post '/game/player/stay' do
  @success = "#{session[:player_name]} a decide de rester."
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false

  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK_AMOUNT
    dwinner("Concessionnaire vient frapper Blackjack.")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner("Concessionnaire vient de busted a #{dealer_total}!")
  elsif dealer_total >= DEALER_MIN
    redirect '/game/compare' 
  else
    @show_dealer_hit_button = true
  end

  erb :game
end 

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer' 
end

get '/game/compare' do
  @show_hit_or_stay_buttons = false
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])

  if player_total > dealer_total
    winner("Votre main est utile #{player_total} et croupier vaut #{dealer_total}.")
  elsif player_total < dealer_total
    loser("Croupier vaut #{dealer_total} et votre main vaut #{player_total}.")
  else
    tie("C'est une cravate a #{player_total}! Aucun vainqueur.")
  end
  
  erb :game
end

get '/finish' do
  erb :finish
end
