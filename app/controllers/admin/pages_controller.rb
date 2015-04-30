class Admin::PagesController < ApplicationController

  before_filter :authenticate_admin!

  def dashboard
    #@newsrack = Newsrack.last
    #@editions = @newsrack.try(:editions)

    @stats = {}
    @stats[:user_count] = User.count
    @stats[:admin_count] = Admin.count
  end


end