$:.unshift File.dirname(__FILE__) # For running the actual JsDuck app

require 'jsduck/lexer'
require 'jsduck/parser'
require 'jsduck/doc_parser'
require 'jsduck/merger'
require 'jsduck/class'
require 'jsduck/tree'
require 'jsduck/doc_links'
require 'jsduck/table'
require 'jsduck/cfg_table'
require 'jsduck/property_table'
require 'jsduck/param_list'
require 'jsduck/method_table'
require 'jsduck/event_table'
require 'jsduck/page'
require 'json'

require 'optparse'
require 'fileutils'
require 'pp'

module JsDuck
  def self.parse(input)
    doc_parser = DocParser.new
    merger = Merger.new
    documentation = []
    current_class = nil

    Parser.new(input).parse.each do |docset|
      node = merger.merge(doc_parser.parse(docset[:comment]), docset[:code])
      # all methods, cfgs, ... following a class will be added to that class
      if node[:tagname] == :class
        current_class = node
        documentation << node
      elsif current_class
        current_class[ node[:tagname] ] << node
      else
        documentation << node
      end
    end

    documentation
  end

  # Given array of filenames, parses all files and returns array of
  # documented items in all of those files.
  def self.parse_files(filenames, verbose)
    docs = []
    filenames.each do |name|
      puts "Parsing #{name} ..." if verbose
      JsDuck.parse(IO.read(name)).each { |d| docs << d }
    end
    docs
  end

  # Filters out class-documentations, converting them to Class objects.
  # For each other type, prints a warning message and discards it
  def self.filter_classes(docs)
    classes = {}
    docs.each do |d|
      if d[:tagname] == :class
        classes[d[:name]] = Class.new(d, classes)
      else
        puts "Warning: Ignoring " + d[:tagname].to_s + ": " + (d[:name] || "")
      end
    end
    classes.values
  end

  def self.print_debug(docs)
    docs.each do |doc|
      puts (doc[:name] || "?") + ":"
      if doc[:tagname] == :class
        [:cfg, :property, :method, :event].each do |key|
          puts "  " + key.to_s + "s:"
          doc[key].each {|item| puts "    " + (item[:name] || "?")}
        end
      end
      puts
    end
  end

  # Given array of doc-objects, generates namespace tree and writes in
  # in JSON form into a file.
  def self.write_tree(filename, docs)
    js = "Docs.classData = " + JSON.generate( Tree.new.create(docs) ) + ";"
    js += "Docs.icons = {};"
    File.open(filename, 'w') {|f| f.write(js) }
  end

  # Writes documentation page for each class
  def self.write_pages(path, docs, verbose)
    docs.each do |cls|
      filename = path + "/" + cls[:name] + ".html"
      puts "Writing to #{filename} ..." if verbose
      File.open(filename, 'w') {|f| f.write( Page.new(cls).to_html ) }
    end
  end
end


if __FILE__ == $0 then
  output_dir = nil
  verbose = false

  opts = OptionParser.new do | opts |
    opts.banner = "Usage: ruby jsduck.rb [options] files..."

    opts.on('-o', '--output=PATH', "Directory to output all this amazing documentation.") do |path|
      output_dir = path
    end

    opts.on('-v', '--verbose', "This will fill up your console.") do
      verbose = true
    end

    opts.on('-h', '--help', "Prints this help message") do
      puts opts
      exit
    end
  end

  input_files = opts.parse!(ARGV)

  if input_files.length == 0
    puts "You should specify some input files, otherwise there's nothing I can do :("
    exit(1)
  elsif !output_dir
    puts "You should also specify an output directory, where I could write all this amazing documentation."
    exit(1)
  elsif !File.exists?(output_dir)
    puts "Output directory doesn't exist.  I'll take the pride of creating it..."
    FileUtils.mkdir(output_dir)
  elsif !File.directory?(output_dir)
    puts "Oh noes!  The output directory is not really a directory at all :("
    exit(1)
  end

  classes = JsDuck.filter_classes(JsDuck.parse_files(input_files, verbose))
  JsDuck.write_tree(output_dir+"/tree.js", classes)
  JsDuck.write_pages(output_dir, classes, verbose)
end

