# name: retort-tbf
# about: Reactions plugin for Discourse
# version: 0.1.1
# authors: James Kiesel (gdpelican), Ivan RL (ivanrlio)
# url: https://github.com/gdpelican/retort

register_asset "stylesheets/retort.scss"
register_asset "stylesheets/retort-style.css"

RETORT_PLUGIN_NAME ||= "retort".freeze

enabled_site_setting :retort_enabled

after_initialize do
  module ::Retort
    class Engine < ::Rails::Engine
      engine_name RETORT_PLUGIN_NAME
      isolate_namespace Retort
    end
  end

  ::Retort::Engine.routes.draw do
    post   "/:post_id" => "retorts#update"
  end

  Discourse::Application.routes.append do
    mount ::Retort::Engine, at: "/retorts"
  end

  class ::Retort::RetortsController < ApplicationController
    before_filter :verify_post_and_user, only: :update

    def update
      retort.toggle_user(current_user)
      respond_with_retort
    end

    private

    def post
      @post ||= Post.find_by(id: params[:post_id]) if params[:post_id]
    end

    def retort
      @retort ||= Retort::Retort.find_by(post: post, retort: params[:retort])
    end

    def verify_post_and_user
      respond_with_unprocessable("Unable to find post #{params[:post_id]}") unless post
      respond_with_unprocessable("You are not permitted to modify this") unless current_user
    end

    def respond_with_retort
      if retort && retort.valid?
        MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}", serialized_retort
        render json: { success: :ok }
      else
        respond_with_unprocessable("Unable to save that retort. Please try again")
      end
    end

    def serialized_retort
      ::Retort::RetortSerializer.new(retort.detail, root: false).as_json
    end

    def respond_with_unprocessable(error)
      render json: { errors: error }, status: :unprocessable_entity
    end
  end

  class ::Retort::RetortSerializer < ActiveModel::Serializer
    attributes :post_id, :usernames, :retort
    define_method :post_id,   -> { object.post_id }
    define_method :usernames, -> { object.persisted? ? JSON.parse(object.value) : [] }
    define_method :retort,    -> { object.key.split('|').first }
  end

  ::Retort::Retort = Struct.new(:detail) do

    def self.for_post(post: nil)
      PostDetail.where(extra: RETORT_PLUGIN_NAME,
                       post: post)
    end

    def self.find_by(post: nil, retort: nil)
      new(for_post(post: post).find_or_initialize_by(key: :"#{retort}|#{RETORT_PLUGIN_NAME}"))
    end

    def valid?
      detail.valid?
    end

    def toggle_user(user)
      new_value = if value.include? user.username
        value - Array(user.username)
      else
        value + Array(user.username)
      end.flatten

      if new_value.any?
        detail.update(value: new_value.flatten)
      else
        detail.destroy
      end
    end

    def value
      return [] unless detail.value
      @value ||= Array(JSON.parse(detail.value))
    end
  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :retorts

    def retorts
      return ActiveModel::ArraySerializer.new(Retort::Retort.for_post(post: object), each_serializer: ::Retort::RetortSerializer).as_json
    end
  end
end
