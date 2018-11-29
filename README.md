# Setup

* Download or clone the project
* Open a terminal window in the project's folder
* Run `bundle install`
  * If you get an error, you may need to look up how to install Ruby (and/or Rails) onto your system
* Run `bundle exec rails s` to launch the Rails web server (depending on your Ruby configuration, entering `rails s` may also work)
* Open a browser and navigate to `localhost:3000`

> Note: The tool isn't configured to stop a simulation currently in progress. When switching between simulations, refresh the page to stop the current simulation before starting the next simulation.

# Todo
* Configure project to display 64x64 and 63x67 matrices
* Implement proper visualization of cache line usage
* Add support for other cache associativities
