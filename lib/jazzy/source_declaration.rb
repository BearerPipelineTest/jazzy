# frozen_string_literal: true

require 'jazzy/source_declaration/access_control_level'
require 'jazzy/source_declaration/type'

module Jazzy
  # rubocop:disable Metrics/ClassLength
  class SourceDeclaration
    # kind of declaration (e.g. class, variable, function)
    attr_accessor :type
    # static type of declared element (e.g. String.Type -> ())
    attr_accessor :typename

    # Give the item its own page or just inline into parent?
    def render_as_page?
      children.any? ||
        (Config.instance.separate_global_declarations &&
         type.global?)
    end

    def swift?
      type.swift_type?
    end

    def highlight_language
      swift? ? Highlighter::SWIFT : Highlighter::OBJC
    end

    # When referencing this item from its parent category,
    # include the content or just link to it directly?
    def omit_content_from_parent?
      Config.instance.separate_global_declarations &&
        render_as_page?
    end

    # Element containing this declaration in the code
    attr_accessor :parent_in_code

    # Logical parent in the documentation. May differ from parent_in_code
    # because of top-level categories and merged extensions.
    attr_accessor :parent_in_docs

    # counterpart of parent_in_docs
    attr_reader :children

    def children=(new_children)
      # Freeze to ensure that parent_in_docs stays in sync
      @children = new_children.freeze
      @children.each { |c| c.parent_in_docs = self }
    end

    # Chain of parent_in_code from top level to self. (Includes self.)
    def namespace_path
      namespace_ancestors + [self]
    end

    def namespace_ancestors
      if parent_in_code
        parent_in_code.namespace_path
      else
        []
      end
    end

    def fully_qualified_name
      namespace_path.map(&:name).join('.')
    end

    # :name doesn't include any generic type params.
    # This regexp matches any generic type params in parent names.
    def fully_qualified_name_regexp
      Regexp.new(namespace_path.map(&:name)
                               .map { |n| Regexp.escape(n) }
                               .join('(?:<.*?>)?\.'))
    end

    # If this declaration is an objc category, returns an array with the name
    # of the extended objc class and the category name itself, i.e.
    # ["NSString", "MyMethods"], nil otherwise.
    def objc_category_name
      name.split(/[()]/) if type.objc_category?
    end

    def swift_objc_extension?
      type.swift_extension? && usr && usr.start_with?('c:objc')
    end

    def swift_extension_objc_name
      return unless type.swift_extension? && usr

      usr.split('(cs)').last
    end

    # The language in the templates for display
    def display_language
      return 'Swift' if swift?

      Config.instance.hide_objc? ? 'Swift' : 'Objective-C'
    end

    def display_declaration
      return declaration if swift?

      Config.instance.hide_objc? ? other_language_declaration : declaration
    end

    def display_other_language_declaration
      other_language_declaration unless
        Config.instance.hide_objc? || Config.instance.hide_swift?
    end

    attr_accessor :file
    attr_accessor :line
    attr_accessor :column
    attr_accessor :usr
    attr_accessor :type_usr
    attr_accessor :modulename
    attr_accessor :name
    attr_accessor :objc_name
    attr_accessor :declaration
    attr_accessor :other_language_declaration
    attr_accessor :abstract
    attr_accessor :default_impl_abstract
    attr_accessor :from_protocol_extension
    attr_accessor :discussion
    attr_accessor :return
    attr_accessor :parameters
    attr_accessor :url
    attr_accessor :mark
    attr_accessor :access_control_level
    attr_accessor :start_line
    attr_accessor :end_line
    attr_accessor :nav_order
    attr_accessor :url_name
    attr_accessor :deprecated
    attr_accessor :deprecation_message
    attr_accessor :unavailable
    attr_accessor :unavailable_message
    attr_accessor :generic_requirements
    attr_accessor :inherited_types
    attr_accessor :async

    def usage_discouraged?
      unavailable || deprecated
    end

    def filepath
      CGI.unescape(url)
    end

    # Base filename (no extension) for the item
    def docs_filename
      result = url_name || name
      # Workaround functions sharing names with
      # different argument types (f(a:Int) vs. f(a:String))
      return result unless type.swift_global_function?

      result + "_#{type_usr}"
    end

    def constrained_extension?
      type.swift_extension? &&
        generic_requirements
    end

    def mark_for_children
      if constrained_extension?
        SourceMark.new_generic_requirements(generic_requirements)
      else
        SourceMark.new
      end
    end

    def inherited_types?
      inherited_types &&
        !inherited_types.empty?
    end

    # Is there at least one inherited type that is not in the given list?
    def other_inherited_types?(unwanted)
      return false unless inherited_types?

      inherited_types.any? { |t| !unwanted.include?(t) }
    end

    # Pre-Swift 5.6: SourceKit only sets modulename for imported modules
    # Swift 5.6+: modulename is always set
    def type_from_doc_module?
      !type.extension? ||
        (swift? && usr &&
          (modulename.nil? || modulename == Config.instance.module_name))
    end

    # Info text for contents page by collapsed item name
    def declaration_note
      notes = [default_impl_abstract ? 'default implementation' : nil,
               from_protocol_extension ? 'extension method' : nil,
               async ? 'asynchronous' : nil].compact
      notes.join(', ').humanize unless notes.empty?
    end

    def alternative_abstract
      if file = alternative_abstract_file
        Pathname(file).read
      end
    end

    def alternative_abstract_file
      abstract_glob.select do |f|
        # allow Structs.md or Structures.md
        [name, url_name].include?(File.basename(f).split('.').first)
      end.first
    end

    def abstract_glob
      return [] unless
        Config.instance.abstract_glob_configured &&
        Config.instance.abstract_glob

      Config.instance.abstract_glob.select { |e| File.file? e }
    end
  end
  # rubocop:enable Metrics/ClassLength
end
