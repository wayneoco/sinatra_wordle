require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'yaml'

WORDS = YAML.load_file('words.yml')

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  # Determines color background of a letter's tile
  def tile_status(word, index)
    return '' if word.nil?

    winning_word = session[:winning_word]

    if green_tile?(word, index, winning_word)
      'green'
    elsif yellow_tile?(word, index, winning_word)
      'yellow'
    else
      'grey'
    end
  end

  # Determines if 'Play Again' button is displayed and if word input is hidden.
  def play_again?
    (session[:winner_message] || session[:loser_message]) &&
      session[:no_more_words_message].nil?
  end
end

# Determines if tile background should be green.
def green_tile?(word, index, winning_word)
  winning_word.include?(word[index]) &&
    winning_word[index] == word[index] &&
    prevent_duplicate_letters?(word, index, winning_word)
end

# Determines if tile background should be yellow.
def yellow_tile?(word, index, winning_word)
  winning_word.include?(word[index]) &&
    winning_word[index] != word[index] &&
    prevent_duplicate_letters?(word, index, winning_word)
end

# Prevents additional instances of the same letter from having a green or yellow
# background if there fewer instances of the same letter in the winning word.
def prevent_duplicate_letters?(word, index, winning_word)
  letter = word[index]

  word.slice(0, index + 1).count(letter) <= winning_word.count(letter)
end

# Input validation. Prevents non-alphabetic characters from being input.
def valid_word?(word)
  word.size == 5 && /[A-Z]{5}/.match?(word.upcase)
end

# Input validation. Prevents duplicate guesses.
def duplicate_guess?(word)
  session[:words].include?(word.upcase)
end

# Determines the appropriate error message for input validation.
def error_message(word)
  invalid_word = 'Word must be exactly 5 alphabetic characters.'
  duplicate_guess = "You've already used #{word.upcase}."

  return invalid_word unless valid_word?(word)

  duplicate_guess if duplicate_guess?(word)
end

# Determines if the correct word has been guessed.
def game_won?
  WORDS[session[:game]] == session[:current_word]
end

# Determines if the user has exhausted all guesses without guessing the
# correct word.
def game_lost?
  session[:words].size == 6 && !game_won?
end

# Determines if the WORD list has been exhausted.
def no_more_words?
  session[:winning_word] == WORDS.last  && (game_won? || game_lost?)
end

# Initializes various session data at first game play.
def initialize_session_data
  session[:winning_word_index] = 0
  session[:winning_word] = WORDS[session[:winning_word_index]]
  session[:words] = []
  session[:number_of_guesses] = []
  session[:wins] = 0
  session[:win_rate] = 0
  session[:current_win_streak] = 0
  session[:best_win_streak] = 0
  session[:average_guesses] = 0
end

# Updates session data after each game round.
def update_session_data
  if session[:winner_message]
    session[:current_win_streak] += 1
    session[:best_win_streak] = session[:current_win_streak] if session[:current_win_streak] > session[:best_win_streak]
    session[:wins] += 1
  else
    session[:current_win_streak] = 0
  end
  session[:game] += 1
  session[:win_rate] = (session[:wins].fdiv(session[:game]) * 100).round(0)
  session[:number_of_guesses] << session[:words].size
  session[:average_guesses] = session[:number_of_guesses].sum.fdiv(session[:number_of_guesses].size).round(1)
end

get '/' do
  session[:game] = 0 if session[:game].nil?
  initialize_session_data if session[:game].zero?

  erb :index
end

post '/' do
  if valid_word?(params[:current_word]) && !duplicate_guess?(params[:current_word])
    session[:words] << params[:current_word].upcase
    session[:current_word] = params[:current_word].upcase
  else
    session[:error_message] = error_message(params[:current_word])
  end

  session[:winner_message] = 'Great job!' if game_won?
  session[:loser_message] = 'Oops! You\'re out of guesses.' if game_lost?
  session[:no_more_words_message] = 'That\'s it! There are no more words!' if no_more_words?
  update_session_data if session[:winner_message] || session[:loser_message]

  erb :index
end

post '/play-again' do
  session.delete(:winner_message) if session[:winner_message]
  session.delete(:loser_message) if session[:loser_message]
  session.delete(:current_word)
  session[:winning_word_index] += 1
  session[:winning_word] = WORDS[session[:winning_word_index]]
  session[:words] = []

  redirect '/'
end

post '/reset' do
  session.delete(:game)
  session.delete(:winner_message) if session[:winner_message]
  session.delete(:loser_message) if session[:loser_message]
  session.delete(:no_more_words_message)
  session.delete(:current_word)

  redirect '/'
end
