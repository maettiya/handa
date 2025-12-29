class ProfileController < ApplicationController
  def show
    @user = current_user
    @storage_breakdown = @user.storage_breakdown
    @total_storage = @user.total_storage_used
  end

  def edit
    @user = current_user
    @field = params[:field]&.to_sym
  end

  def update
    @user = current_user

    if avatar_update?
      @user.avatar.attach(params[:user][:avatar])
      redirect_to profile_path
    elsif @user.update(profile_params)
      redirect_to profile_path
    else
      @field = params[:user].keys.first&.to_sym
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def avatar_update?
    params[:user] && params[:user][:avatar].present?
  end

  def profile_params
    params.require(:user).permit(:username, :email, :password, :password_confirmation)
  end
end
