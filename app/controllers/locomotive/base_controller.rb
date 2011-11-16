module Locomotive
  class BaseController < ApplicationController

    include Locomotive::Routing::SiteDispatcher

    layout '/locomotive/layouts/application'

    before_filter :require_account

    before_filter :require_site

    before_filter :validate_site_membership

    load_and_authorize_resource

    before_filter :set_locale

    before_filter :set_current_thread_variables

    helper_method :sections, :current_site_url, :site_url, :public_page_url, :current_ability

    # https://rails.lighthouseapp.com/projects/8994/tickets/1905-apphelpers-within-plugin-not-being-mixed-in
    helper Locomotive::BaseHelper, Locomotive::ContentTypesHelper #, Locomotive::BoxHelper
    # Dir[File.dirname(__FILE__) + "/../../helpers/**/*_helper.rb"].each do |file|
    #   helper "locomotive/#{File.basename(file, '.rb').gsub(/_helper$/, '')}"
    # end

    self.responder = Locomotive::Responder # custom responder

    respond_to :html

    rescue_from CanCan::AccessDenied do |exception|
      ::Locomotive.log "[CanCan::AccessDenied] #{exception.inspect}"

      if request.xhr?
        render :json => { :error => exception.message }
      else
        flash[:alert] = exception.message

        redirect_to pages_url
      end
    end

    protected

    def set_current_thread_variables
      Thread.current[:account] = current_locomotive_account
      Thread.current[:site]  = current_site
    end

    def current_ability
      @current_ability ||= Ability.new(current_locomotive_account, current_site)
    end

    def require_account
      authenticate_locomotive_account!
    end

    def self.sections(main, sub = nil)
      before_filter do |c|
        sub = sub.call(c) if sub.respond_to?(:call)
        sections = { :main => main, :sub => sub }
        c.instance_variable_set(:@locomotive_sections, sections)
      end
    end

    def sections(key = nil)
      if !key.nil? && key.to_sym == :sub
        @locomotive_sections[:sub] || self.controller_name.dasherize
      else
        @locomotive_sections[:main]
      end
    end

    def set_locale
      I18n.locale = current_locomotive_account.locale rescue Locomotive.config.default_locale
    end

    # ___ site/page urls builder ___

    def current_site_url
      request.protocol + request.host_with_port
    end

    def site_url(site, options = {})
      options = { :fullpath => true, :protocol => true }.merge(options)

      url = "#{site.subdomain}.#{Locomotive.config.domain}"
      url += ":#{request.port}" if request.port != 80

      url = File.join(url, request.fullpath) if options[:fullpath]
      url = "http://#{url}" if options[:protocol]
      url
    end

    def public_page_url(page, options = {})
      if content = options.delete(:content)
        File.join(current_site_url, page.fullpath.gsub('content_type_template', ''), content._slug)
      else
        File.join(current_site_url, page.fullpath)
      end
    end


  end
end
