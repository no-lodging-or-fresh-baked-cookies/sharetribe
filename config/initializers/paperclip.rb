Paperclip::UriAdapter.register
Paperclip::DataUriAdapter.register
Paperclip::HttpUrlProxyAdapter.register

module Paperclip
  Attachment.class_eval do
    def assign(uploaded_file)
      @file = Paperclip.io_adapters.for(uploaded_file,
                                        @options[:adapter_options])
      ensure_required_accessors!
      ensure_required_validations!

      if @file.assignment?
        clear(*only_process)

        if @file.nil?
          nil
        else
          assign_attributes
          convert_heic_to_well_known_image
          post_process_file
          reset_file_if_original_reprocessed
        end
      else
        nil
      end
    end

    private

    def convert_heic_to_well_known_image
      return unless ['image/heic', 'image/heif'].include?(@file.content_type)
      style = Paperclip::Style.new(:original_png, ["#{APP_CONFIG.original_image_width}x#{APP_CONFIG.original_image_height}>", :png], self)
      post_process_style(:original, style)
      reset_file_if_original_reprocessed
      instance_write(:file_name, "#{@file.original_filename}.png")
      instance_write(:content_type, "image/png")
    end
  end
end

module DelayedPaperclip
  class ProcessJob < ActiveJob::Base
    def self.enqueue_delayed_paperclip(instance_klass, instance_id, attachment_name)
      delayed_opts = instance_klass.constantize.paperclip_definitions[attachment_name][:delayed]

      # DelayedPaperclip sets priority to 0 (highest) by default, so we switch
      # the default to 5, as it is the default for all other jobs.
      priority = delayed_opts[:priority] > 0 ? delayed_opts[:priority] : 5

      set(:queue => delayed_opts[:queue_name], priority: priority).perform_later(instance_klass, instance_id, attachment_name.to_s)
    end
  end
end
