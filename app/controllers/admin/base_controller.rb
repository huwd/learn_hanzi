module Admin
  class BaseController < ApplicationController
    include AdminAuthentication
  end
end
