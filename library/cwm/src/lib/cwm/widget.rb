require "yast"

require "abstract_method"

module CWM
  # Represent base for any widget used in CWM. It can be passed as "widget" argument. For more
  # details about usage see {CWM.ShowAndRun}
  #
  # For using widgets design decision is to use subclassing. Reason is to have better separeated
  # and easily reusable code. Opposite approach is to use instancing of existing classes, but
  # especially with storing and initializing widgets it can be quite complex. Consider e.g.
  # instancing of InputField like:
  #
  # ```
  #   widget = InputField.new(
  #     label: _("My label"),
  #     help: _("blablbalba" \
  #       "blablabla" \
  #       "blablabla"
  #     ),
  #     init: Proc.new do |widget|
  #       ...
  #     end,
  #     store: Proc.new do |widget, event|
  #       ...
  #     end,
  #     validate: Proc.new do |widget, event|
  #       ....
  #     end
  #   )
  # ```
  #
  # For this example current subclassing approach looks like
  # ```
  #   class MyWidget < CWM::InputField
  #     def label
  #       _("My label")
  #     end
  #
  #     def help
  #       _("blablbalba" \
  #         "blablabla" \
  #         "blablabla"
  #     end
  #
  #     def init
  #       ...
  #     end
  #
  #     def store
  #       ...
  #     end
  #
  #     def validate
  #       ....
  #     end
  #   end
  #  # and usage in dialog
  #  widget = MyWidget.new
  # ```
  #
  class AbstractWidget
    include Yast::UIShortcuts
    include Yast::I18n

    # @return [String] id used for widget
    attr_writer :widget_id
    attr_writer :handle_all_events

    # specify if widget handle all raised events or only its own
    # By default only own values are handled
    def handle_all_events
      @handle_all_events.nil? ? false : @handle_all_events
    end

    def widget_id
      @widget_id || self.class.to_s
    end

    # defines widget type for CWM usage
    def self.widget_type=(val)
      define_method(:widget_type) { val }
    end

    # generates widget definition for CWM. Definition is constructed from defined methods.
    #
    # methods used to generate result:
    #
    # - `#help` [String] to get translated help text for widget
    # - `#label` [String] to get translated label text for widget
    # - `#opt` [Array<Symbol>] to get options passed to widget like `[:hstretch, :vstretch]`
    # - `#validate` [Boolean ()] validate widget value. Returns false if validation failed.
    # - `#init` [nil ()] initialize widget like e.g. set initial value
    # - `#handle` [Symbol,nil (String?)] handle widget changed value or press.
    #   return value is usually nil, returning symbol can be used to send different event.
    #   It support varient with parameter specified and without. If parameter is specified,
    #   gets event Hash including "ID" key with value that specify widget ID that cause event.
    #   It is mainly useful if handle_all_events is set to true to distinguish which event caused it.
    # - `#store` [nil ()] store widget value after user confirm dialog
    # - `#cleanup` [nil ()] cleanup after widget is destroyed
    # @raise [RuntimeError] if required method is not implemented or widget id not set.
    def cwm_definition
      if !respond_to?(:widget_type)
        raise "Widget '#{self.class}' does set its widget type"
      end

      res = {}

      if respond_to?(:help)
        res["help"] = help
      else
        res["no_help"] = ""
      end
      res["label"] = label if respond_to?(:label)
      res["opt"] = opt if respond_to?(:opt)
      if respond_to?(:validate)
        res["validate_function"] = validate_method
        res["validate_type"] = :function
      end
      res["handle_events"] = [widget_id] unless handle_all_events
      res["init"] = init_method if respond_to?(:init)
      res["handle"] = handle_method if respond_to?(:handle)
      res["store"] = store_method if respond_to?(:store)
      res["cleanup"] = cleanup_method if respond_to?(:cleanup)
      res["widget"] = widget_type

      res
    end

    # gets if widget is open for modification
    def enabled?
      Yast::UI.QueryWidget(Id(widget_id), :Enabled)
    end

    # Opens widget for modification
    def enable
      Yast::UI.ChangeWidget(Id(widget_id), :Enabled, true)
    end

    # Closes widget for modification
    def disable
      Yast::UI.ChangeWidget(Id(widget_id), :Enabled, false)
    end

  protected

    # helper to check if event is invoked by this widget
    def my_event?(event)
      widget_id == event["ID"]
    end

    # shortcut from Yast namespace to avoid including whole namespace
    # TODO: kill converts in CWM module, to avoid this workaround for funrefs
    def fun_ref(*args)
      Yast::FunRef.new(*args)
    end

  private

    # @note all methods here use wrappers to modify required parameters as CWM
    # have not so nice callbacks API
    def init_method
      fun_ref(method(:init_wrapper), "void (string)")
    end

    def init_wrapper(_widget)
      init
    end

    def handle_method
      fun_ref(method(:handle_wrapper), "symbol (string, map)")
    end

    # allows both variant of handle. with event map and without.
    # with map it make sense when handle_all_events is true or in custom widgets
    # with multiple elements, that generate events, otherwise map is not needed
    def handle_wrapper(_widget, event)
      m = method(:handle)
      if m.arity == 0
        m.call
      else
        m.call(event)
      end
    end

    def store_method
      fun_ref(method(:store_wrapper), "void (string, map)")
    end

    def store_wrapper(_widget, _event)
      store
    end

    def cleanup_method
      fun_ref(method(:cleanup_wrapper), "void (string)")
    end

    def cleanup_wrapper(_widget)
      cleanup
    end

    def validate_method
      fun_ref(method(:validate_wrapper), "boolean (string, map)")
    end

    def validate_wrapper(_widget, _event)
      validate
    end
  end

  # Represents custom widget, that have its UI content defined in method content.
  # Useful mainly when specialized widget including more subwidget should be
  # reusable at more places.
  #
  # @example custom widget child
  #   class MyWidget < CWM::CustomWidget
  #     def initialize
  #       self.widget_id = "my_widget"
  #     end
  #
  #     def contents
  #       HBox(
  #         PushButton(Id(:reset), _("Reset")),
  #         PushButton(Id(:undo), _("Undo"))
  #       )
  #     end
  #
  #     def handle(widget, event)
  #       case event["ID"]
  #       when :reset then ...
  #       when :undo then ...
  #       else ...
  #       end
  #     end
  #   end
  class CustomWidget < AbstractWidget
    self.widget_type = :custom
    # custom witget without contents do not make sense
    abstract_method :contents

    def cwm_definition
      res = { "custom_widget" => contents }

      res["handle_events"] = ids_in_contents unless handle_all_events

      super.merge(res)
    end

  private

    def ids_in_contents
      find_ids(contents) << widget_id
    end

    def find_ids(term)
      term.each_with_object([]) do |arg, res|
        next unless arg.is_a? Yast::Term

        if arg.value == :id
          res << arg.params[0]
        else
          res.concat(find_ids(arg))
        end
      end
    end
  end

  # Empty widget useful mainly as place holder for replacement or for catching global events
  #
  # @example empty widget usage
  #   widget = CWM::EmptyWidget("replace_point")
  #   CWM.ShowAndRun(
  #     "contents" => VBox(widget.widget_id),
  #     "widgets" => [widget]
  #   )
  class EmptyWidget < AbstractWidget
    self.widget_type = :empty

    def initialize(id)
      self.widget_id = id
    end
  end

  # helpers for easier set/obtain value of widget for widgets where value is
  # obtained by :Value symbol
  module ValueBasedWidget
    def value
      Yast::UI.QueryWidget(Id(widget_id), :Value)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :Value, val)
    end
  end

  # helper to define items used by widgets that offer selection from list of
  # values.
  module ItemsSelection
    # items are defined as list of pair, where first one is id and second
    # one is user visible value
    # @return [Array<Array<String>>]
    # @example items method in widget
    #   def items
    #     [
    #       [ "Canada", _("Canada")],
    #       [ "USA", _("United States of America")],
    #       [ "North Pole", _("Really cold place")],
    #     ]
    #   end
    def items
      []
    end

    def cwm_definition
      super.merge(
        "items" => items
      )
    end

    # change list of items offered in widget. Format is same as in {#items}
    def change_items(items_list)
      val = items_list.map { |i| Item(Id(i[0]), i[1]) }

      Yast::UI.ChangeWidget(Id(widget_id), :Items, val)
    end
  end

  # Represents input field widget. `label` method is mandatory.
  #
  # @example input field widget child
  #   class MyWidget < CWM::InputFieldWidget
  #     def initialize(myconfig)
  #       self.widget_id = "my_widget"
  #       @config = myconfig
  #     end
  #
  #     def label
  #       _("The best widget ever is:")
  #     end
  #
  #     def init(_widget)
  #       self.value = @config.value
  #     end
  #
  #     def store(_widget, _event)
  #       @config.value = value
  #     end
  #   end
  class InputFieldWidget < AbstractWidget
    self.widget_type = :inputfield

    include ValueBasedWidget
    abstract_method :label
  end

  # Represents password widget. `label` method is mandatary
  #
  # @see InputFieldWidget for example of child
  class PasswordWidget < AbstractWidget
    self.widget_type = :password

    include ValueBasedWidget
    abstract_method :label
  end

  # Represents password widget. `label` method is mandatary
  #
  # @see InputFieldWidget for example of child
  class CheckboxWidget < AbstractWidget
    self.widget_type = :checkbox

    include ValueBasedWidget
    abstract_method :label

    # @return [Boolean] true if widget is checked
    def checked?
      value
    end

    # @return [Boolean] true if widget is unchecked
    def unchecked?
      !value
    end

    # checks given widget
    def check
      self.value = true
    end

    # Unchecks given widget
    def uncheck
      self.value = false
    end
  end

  # Widget representing combobox to select value.
  #
  # @example combobox widget child
  #   class MyWidget < CWM::InputFieldWidget
  #     def initialize(myconfig)
  #       self.widget_id = "my_widget"
  #       @config = myconfig
  #     end
  #
  #     def label
  #       _("Choose carefully:")
  #     end
  #
  #     def init(_widget)
  #       self.value = @config.value
  #     end
  #
  #     def store(_widget, _event)
  #       @config.value = value
  #     end
  #
  #     def items
  #       [
  #         [ "Canada", _("Canada")],
  #         [ "USA", _("United States of America")],
  #         [ "North Pole", _("Really cold place")],
  #       ]
  #     end
  #   end
  class ComboBoxWidget < AbstractWidget
    self.widget_type = :combobox

    include ValueBasedWidget
    include ItemsSelection
    abstract_method :label
  end

  # Widget representing selection box to select value.
  #
  # @see {ComboBoxWidget} for child example
  class SelectionBoxWidget < AbstractWidget
    self.widget_type = :selection_box

    include ItemsSelection
    abstract_method :label

    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentItem)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, val)
    end
  end

  # Widget representing multi selection box to select more values.
  #
  # @see {ComboBoxWidget} for child example
  class MultiSelectionBoxWidget < AbstractWidget
    self.widget_type = :multi_selection_box

    include ItemsSelection
    abstract_method :label

    # @return [Array<String>] return ids of selected items
    def value
      Yast::UI.QueryWidget(Id(widget_id), :SelectedItems)
    end

    # @param [Array<String>] val array of ids for newly selected items
    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :SelectedItems, val)
    end
  end

  # Represents integer field widget. `label` method is mandatary. It supports
  # additional `minimum` and `maximum` method for limiting selection.
  # @see #{.cwm_definition} method for minimum and maximum example
  #
  # @see InputFieldWidget for example of child
  class IntField < AbstractWidget
    self.widget_type = :intfield

    include ValueBasedWidget
    abstract_method :label

    # definition for combobox additionally support `minimum` and `maximum` methods.
    # Both methods have to FixNum, where it is limited by C signed int range (-2**30 to 2**31-1).
    # @example minimum and maximum methods
    #   def minimum
    #     50
    #   end
    #
    #   def maximum
    #     200
    #   end
    #
    def cwm_definition
      res = {}

      res["minimum"] = minimum if respond_to?(:minimum)
      res["maximum"] = maximum if respond_to?(:maximum)

      super.merge(res)
    end
  end

  # Widget representing selection of value via radio buttons.
  #
  # @see {ComboBoxWidget} for child example
  class RadioButtonsWidget < AbstractWidget
    self.widget_type = :radio_buttons

    include ItemsSelection
    abstract_method :label

    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentButton)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentButton, val)
    end
  end

  # Widget representing button.
  #
  # @example push button widget child
  #   class MyEvilWidget < CWM::PushButtonWidget
  #     def initialize
  #       self.widget_id = "my_evil_widget"
  #     end
  #
  #     def label
  #       _("Win lottery by clicking this.")
  #     end
  #
  #     def handle(widget, _event)
  #       return if widget != widget_id
  #
  #       Virus.install
  #
  #       nil
  #     end
  #   end
  class PushButtonWidget < AbstractWidget
    self.widget_type = :push_button
  end

  # Widget representing menu button with its submenu
  class MenuButtonWidget < AbstractWidget
    self.widget_type = :menu_button

    include ItemsSelection
    abstract_method :label
  end

  # Multiline text widget
  # @note label method is required and used as default value (TODO: incosistent with similar richtext in CWM itself)
  class MultiLineEditWidget < AbstractWidget
    self.widget_type = :multi_line_edit

    include ValueBasedWidget
    abstract_method :label
  end

  # Rich text widget supporting some highlighting
  class RichTextWidget < AbstractWidget
    self.widget_type = :richtext

    include ValueBasedWidget
  end
end
