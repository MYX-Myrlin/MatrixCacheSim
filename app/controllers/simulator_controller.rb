class SimulatorController < ApplicationController
  def thirtytwo
    @height = 32
    @width = 32
  end

  def sixtyfour
    @height = 64
    @width = 64
  end

  def sixtythree
    @height = 63
    @width = 67
  end
end
