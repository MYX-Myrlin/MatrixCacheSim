Rails.application.routes.draw do
  # Use the menu page as the root page
  root 'menu#index'
  # Available pages
  get 'menu/index'
  get 'simulator/ThirtyTwo'
  get 'simulator/SixtyFour'
  get 'simulator/SixtyThree'
end
