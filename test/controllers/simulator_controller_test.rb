require 'test_helper'

class SimulatorControllerTest < ActionDispatch::IntegrationTest
  test "should get ThirtyTwo" do
    get simulator_ThirtyTwo_url
    assert_response :success
  end

  test "should get SixtyFour" do
    get simulator_SixtyFour_url
    assert_response :success
  end

  test "should get SixtyThree" do
    get simulator_SixtyThree_url
    assert_response :success
  end

end
