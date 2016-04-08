module Tracer
  module Changes

    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods

      def log_record_changes(options = {})
        send :include, InstanceMethods

        class_attribute :changes_logging_options
        self.changes_logging_options = options.dup

        %i(ignore skip only).each do |k|
          changes_logging_options[k] =
              [changes_logging_options[k]].flatten.compact.map { |attr| attr.is_a?(Hash) ? attr.stringify_keys : attr.to_s }
        end

        options_on = Array.wrap(options[:on]) # so that a single symbol can be passed in without wrapping it in an `Array`

        after_create  :log_create, :if => :log_changes? if options_on.empty? || options_on.include?(:create)

        if options_on.empty? || options_on.include?(:update)
          before_update :log_update, :if => :log_changes?
        end

        after_destroy :log_destroy, :if => :log_changes? if options_on.empty? || options_on.include?(:destroy)
      end

    end


    module InstanceMethods

      private


      def log_create
        Tracer::Client.log_changes(
            item_id:   id,
            item_type: self.class.base_class.name,
            event:     'create',
            changes:   changes_for_tracing,
        )
      rescue => e
        Log.exception_with_alert(e, 'Ошибка регистрации создания', 'log_changes create',
                                 item_id:   id,
                                 item_type: self.class.base_class.name)
      end


      def log_update
        if changed_notably?
          Tracer::Client.log_changes(
              item_id:   id,
              item_type: self.class.base_class.name,
              event:     'update',
              object:    object_attrs_for_tracing(item_before_change),
              changes:   changes_for_tracing,
          )
        end
      rescue => e
        Log.exception_with_alert(e, 'Ошибка регистрации изменения', 'log_changes update',
                                 item_id:   id,
                                 item_type: self.class.base_class.name)
      end


      def log_destroy
        if persisted?
          Tracer::Client.log_changes(
              item_id:   id,
              item_type: self.class.base_class.name,
              event:     'destroy',
              object:    object_attrs_for_tracing(item_before_change),
          )
        end
      rescue => e
        Log.exception_with_alert(e, 'Ошибка регистрации удаления', 'log_changes destroy',
                                 item_id:   id,
                                 item_type: self.class.base_class.name)
      end


      def object_attrs_for_tracing(object)
        object_attrs = object.attributes.except(*changes_logging_options[:skip]).with_indifferent_access

        unwrap_serialized_attributes(object_attrs) do |object_attrs, values, attr|
          object_attrs[attr] = values[attr] if values.key?(attr)
        end

        object_attrs.as_json
      end


      def changes_for_tracing
        changed = self.changes.delete_if do |key, value|
          !notably_changed.include?(key)
        end

        unwrap_serialized_attributes(changed) do |changed, (a, b), attr|
          if (a.key?(attr) || b.key?(attr)) && a[attr] != b[attr]
            changed[attr] = [a[attr], b[attr]]
          end
        end

        changed.as_json
      end


      # attrs должны быть либо с ключами-символами, либо HashWithIndifferentAccess
      def unwrap_serialized_attributes(attrs)
        stored_attrs = self.class.stored_attributes
        serialized = attrs.extract!(*stored_attrs.keys)

        serialized.each do |store_attr, value|
          stored_attrs[store_attr.to_sym].each do |attr|
            yield(attrs, value, attr)
          end
        end
      end


      def item_before_change
        previous = self.dup
        # `dup` clears timestamps so we add them back.
        all_timestamp_attributes.each do |column|
          previous[column] = send(column) if self.class.column_names.include?(column.to_s) and not try(column).nil?
        end
        previous.tap do |prev|
          prev.id = id # `dup` clears the `id` so we add that back
          changed_attributes.select { |k,v| self.class.column_names.include?(k) }.each { |attr, before| prev[attr] = before }
        end
      end


      def changed_notably?
        notably_changed.any?
      end


      def notably_changed
        only = self.changes_logging_options[:only].dup
        # remove Hash arguments and then evaluate whether the attributes (the keys of the hash) should also get pushed into the collection
        only.delete_if do |obj|
          obj.is_a?(Hash) && obj.each { |attr, condition| only << attr if condition.respond_to?(:call) && condition.call(self) }
        end
        only.empty? ? changed_and_not_ignored : (changed_and_not_ignored & only)
      end

      def changed_and_not_ignored
        ignore = self.changes_logging_options[:ignore].dup
        # remove Hash arguments and then evaluate whether the attributes (the keys of the hash) should also get pushed into the collection
        ignore.delete_if do |obj|
          obj.is_a?(Hash) && obj.each { |attr, condition| ignore << attr if condition.respond_to?(:call) && condition.call(self) }
        end
        skip = self.changes_logging_options[:skip]
        changed - ignore - skip
      end

    end


    def log_changes?
      if_condition     = self.changes_logging_options[:if]
      unless_condition = self.changes_logging_options[:unless]
      (if_condition.blank? || if_condition.call(self)) && !unless_condition.try(:call, self)
    end

  end
end

ActiveSupport.on_load(:active_record) do
  include Tracer::Changes
end
