class Api::SessionsController < ApplicationController
  before_filter :authenticate_user!, :only => [:update_profile]
  skip_before_filter :detect_email_omniauth

  def sign_in
    if params[:user_email] && params[:user_password]
      password_email_sign_in
    elsif params[:uid]
      social_sign_in
    else
      render :json => {:error => true, :description => "No params provided"}, status: 401 and return
    end
  end

  def sign_up
    if params[:user_email] && params[:user_password]
      password_email_sign_up
    elsif params[:user_email] && params[:uid]
      social_sign_up
    else
      render :json => {:error => true, :description => "No params provided"}, status: 401 and return
    end
  end

  def update_profile
    begin
      @user = User.find_by_authentication_token(params[:auth_token])
      if @user.update_attributes(params[:session])
        render :json => {:error => false, :description => "User saved."} and return
      else
        if !@user.errors.messages.empty?
          render :json => {:error => true, :description => "Error saving user.", :errors => @user.errors.messages}, status: 500 and return
        else
          render :json => {:error => true, :description => "Error saving user."}, status: 500 and return
        end
      end
    rescue Exception => e
      render :json => {:error => true, :description => "Internal Server Error."}, status: 503 and return
    end
  end

  private
  def password_email_sign_up
    begin
      @user = User.new(email: params[:user_email], password: params[:user_password])
      if @user.save
        UserMailer.signupsuccess(@user).deliver
        render :json => {:error => false, :description => "User saved.", :auth_token => @user.authentication_token}
      else
        if !@user.errors.messages.empty?
          render :json => {:error => true, :description => "Error saving user.", :errors => @user.errors.messages}, status: 500 and return
        else
          render :json => {:error => true, :description => "Error saving user."}, status: 500 and return
        end
      end
    rescue Exception => e
      render :json => {:error => true, :description => "Internal Server Error."}, status: 503 and return
    end
  end

  def password_email_sign_in
    begin
      @user = User.find_by_email(params[:user_email])
      if @user.nil?
        render :json => {:error => true, :description => "No params provided"}, status: 401 and return
      end
      if @user.valid_password?(params[:user_password])
        @auth_code = @user.authentication_token
      else
        render :json => {:error => true, :description => "Wrong password."}, status: 401 and return
      end
      render :json => {:error => false, :auth_token => "#{@auth_code}"}
    rescue Exception => e
      render :json => {:error => true, :description => "Internal Server Error."}, status: 503 and return
    end
  end

  # NOTE: this needs access control. Some way to make sure the requests are coming from the mobile app.
  # A hardcoded sha might be enough (api keys for the apps?)
  def social_sign_up
    user = nil
    external_uid = nil
    success_message = nil
    ActiveRecord::Base.transaction do
      user = User.where(email: params[:user_email]).first_or_initialize
      success_message = "User retrieved."
      if user.new_record?
        success_message = "User saved."
        user.do_password_validation = false
        UserMailer.signupsuccess(user).deliver
        return unless user.save
      end
      external_uid = ExternalUID.where(uid: params[:uid], user_id: user.id).first_or_initialize
      if external_uid.new_record?
        raise ActiveRecord::Rollback unless external_uid.save
      end
    end
    if user.persisted? && external_uid.persisted?
      render :json => {:error => false, :description => success_message, :auth_token => user.authentication_token}
    else
      errors = {}
      errors[:user] = user.errors.messages if user.errors.any?
      errors[:uid] = external_uid.errors.messages if external_uid.errors.any?
      render :json => {:error => true, :description => "Error saving user", :errors => errors}, status: 500
    end
  rescue Exception => e
    render :json => {:error => true, :description => "Internal Server Error."}, status: 503 and return
  end

  def social_sign_in
    if external_uid = ExternalUID.where(uid: params[:uid]).first
      @auth_code = external_uid.user.authentication_token
      render :json => {:error => false, :description => "User retrieved.", :auth_token => "#{@auth_code}"}
    else
      render :json => {:error => true, :description => "Wrong uid."}, status: 401
    end
  end
end
