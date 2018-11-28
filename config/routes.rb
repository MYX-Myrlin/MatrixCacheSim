Rails.application.routes.draw do
  # Use the menu page as the root page
  root 'menu#index'
  # Available pages
  get 'menu/index'
  get 'simulator/thirtytwo'
  get 'simulator/sixtyfour'
  get 'simulator/sixtythree'
end
