class ShareLinksController < ApplicationController
  before_action :authenticate_user!, only: [:create, :destroy]
  before_action :set_share_link, only: [:show, :download, :verify_password]
  before_action :set_project, only: [:create]



end
