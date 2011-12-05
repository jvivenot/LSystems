#!/usr/bin/env ruby
require 'libglade2'
require 'optparse'
require 'ostruct'

Axiome = "Axiome"
Regle = "Regle"
Regle2 = "Post Regle"
Line = "Ligne"
Blank = "Blank"
Angle = "Angle"

$width = 500
$height = 500

class LSystems
  class << self
    attr_accessor :lines,:blanks,:angles,:maxx,:maxy,:minx,:miny,:box,:lines_to_draw
  end

  include GetText
  attr :glade

  def initialize(path_or_data, root = nil, domain = nil, localedir = nil, flag = GladeXML::FILE)
    bindtextdomain(domain, localedir, nil, "UTF-8")
    @glade = GladeXML.new(path_or_data, root, domain, localedir, flag) {|handler| method(handler)}
    @entry1 = @glade["entry1"]
    @entry2 = @glade["entry2"]
    @entry3 = @glade["entry3"]
    @combobox1 = @glade["combobox1"]
    @ok = @glade["button7"]
    @cancel = @glade["button8"]
    @textview = @glade["textview1"]

    @editing_state = 0 #0 nothing, 1 new, 2 edit
    @liststore = Gtk::ListStore.new(String,String,String)
    @liststore2 = Gtk::ListStore.new(String)
    @combobox1.model = @liststore2
    @listview = @glade["treeview1"]
    @listview.model = @liststore
    text_column = 0
    color_column = 4
    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new("Type", renderer,
                                     :text => text_column,
                                     :foreground => color_column)
    @listview.append_column(column)
    column = Gtk::TreeViewColumn.new("Parametre principal", renderer,
                                     :text => text_column + 1,
                                     :foreground => color_column + 1)
    @listview.append_column(column)
    column = Gtk::TreeViewColumn.new("Parametre secondaire", renderer,
                                     :text => text_column + 2 ,
                                     :foreground => color_column + 2)
    @listview.append_column(column)

    [Axiome, Regle, Regle2, Line, Blank, Angle].each {|x| @combobox1.append_text x}
    set_invisible

    base_rules = [[Axiome,"F++F++F",""],
      [Regle, "F", "F-F++F-F"],
      [Line,"F","1"],
      [Angle,"+","60"],
      [Angle,"-","-60"]
    ]
    base_rules = [[Axiome,"AB",""],
      [Regle, "A", "AA"],
      [Regle, "B", "[+AB][-AB]"],
      [Line,"A","1"],
      [Line,"B","1"],
      [Angle,"+","60"],
      [Angle,"-","-60"]
    ]
    base_rules.each {|x|
      iter = @liststore.append
      @liststore.set_value(iter,0,x[0])
      @liststore.set_value(iter,1,x[1])
      @liststore.set_value(iter,2,x[2])
    }

    @entry3.text = "2"
  end

  def treat(str)
    result = String.new
    str.each_byte{|y|
      x = y.chr
      found = false
      i = 0
      until found || i == @regles.length
        if @regles[i][0] == x then
          found = true
          result << @regles[i][1]
        end
        i += 1
      end
      result << x unless found
    }
    post_treat(result)
  end

  def post_treat(str)
    postresult = String.new
    str.each_byte{|y|
      x = y.chr
      found = false
      i = 0
      until found || i == @postregles.length
        if @postregles[i][0] == x then
          found = true
          postresult << @postregles[i][1]
        end
        i += 1
      end
      postresult << x unless found
    }
    postresult
  end

  def drawable?(str)
    found = true
    str.each_byte{|z|
      y = z.chr
      partial_found = false
      LSystems.angles.each{|x|
        if x[0] == y then partial_found = true end
      }
      LSystems.lines.each{|x|
        if x[0] == y then partial_found = true end
      }
      LSystems.blanks.each{|x|
        if x[0] == y then partial_found = true end
      }
      if ["[","]"].include? y then partial_found = true end
      found &&= partial_found
    }
    found
  end

  def message(txt)
    @textview.buffer.insert_at_cursor txt + "\n"
  end

  def set_invisible
    @entry1.visible = false
    @entry2.visible = false
    @combobox1.visible = false
    @ok.visible = false
    @cancel.visible = false
  end

  def set_visible
    @entry1.visible = true
    @entry2.visible = true
    @combobox1.visible = true
    @ok.visible = true
    @cancel.visible = true
  end

  def add(widget)
    if @editing_state == 0 then
      set_visible
      @editing_state = 1
    else
      message("Arretez tout autre action avant d'ajouter une entree...")
    end
  end

  def edit(widget)
    if @editing_state == 0 then
      found = false
      data = nil
      @listview.selection.selected_each{|model,path,iter|
        found = true
        @selected = iter
      }
      if found then
        @entry1.text = @selected[1]
        @entry2.text = @selected[2]
        set_visible
        @editing_state = 2
      else
        message("Aucune entree de selectionnee, donc rien a editer...")
      end
    else
      message("Arretez tout autre action avant d'ajouter une entree...")
    end
  end

  def ok(widget)
    if @editing_state == 2 then @liststore.remove @selected end
    iter = @liststore.append
    @liststore.set_value(iter,0,@combobox1.active_text)
    @liststore.set_value(iter,1,@entry1.text)
    @liststore.set_value(iter,2,@entry2.text)
    cancel(widget)
  end

  def remove(widget)
    found = false
    @listview.selection.selected_each{|model,path,iter|
      found = true
      @selected = iter
    }
    if found then
      @liststore.remove @selected
    else 
      message("Aucune entree selectionnee !")
    end
  end

  def cancel(widget)
    set_invisible
    @editing_state = 0
    @entry1.text = ""
    @entry2.text = ""
  end

  def open(widget)
    puts "open() is not implemented yet."
  end

  def save(widget)
    puts "save() is not implemented yet."
  end

  def verify
    free_everything
    error = false
    @liststore.each{ |model,path,iter| 
      if iter[1].length != 1 && iter[0] != Axiome then
        message("Erreur : un parametre principal est mal defini...")
        error = true
      end
      case iter[0]
      when Axiome
        if @axiome != nil then 
          message("Erreur : deux axiomes ou plus definis !")
          error = true
        else
          @axiome = iter[1]
        end
      when Regle
        @regles << [iter[1],iter[2]]
      when Regle2
        @postregles << [iter[1],iter[2]]
      when Line
        if iter[2].to_i == 0 then
          message "Erreur : Parametre secondaire de ligne invalide"
          error = true
        end
        LSystems.lines << [iter[1],iter[2]]
      when Blank
        if iter[2].to_i == 0 then
          message "Erreur : Parametre secondaire de blanc invalide"
          error = true
        end
        LSystems.blanks << [iter[1],iter[2]]
      when Angle
        if iter[2].to_i == 0 then
          message "Erreur : Parametre secondaire d'angle invalide"
          error = true
        end
        LSystems.angles << [iter[1],iter[2]]
      end
    }
    unless drawable?(post_treat(treat(@axiome)))
      message "Erreur : L'axiome n'est pas dessinable (meme apres post traitement)"
      error = true
    end
    @regles.each {|r|
      unless drawable?(post_treat(r[1]))
        message "Erreur : Le resultat d'une regle n'est pas dessinable (meme apres post traitement)"
        error = true
      end
    }
    @postregles.each {|r|
      unless drawable?(r[1])
        message "Erreur : Le resultat d'une postregle n'est pas dessinable"
        error = true
      end
    }
    !error
  end

  def free_everything
    @axiome = nil
    @regles = Array.new
    @postregles = Array.new
    LSystems.lines = Array.new
    LSystems.blanks = Array.new
    LSystems.angles = Array.new
  end

  def str2lines(str)
    result = Array.new
    @curx = 0
    @cury = 0
    @curangle = 0
    LSystems.maxx = 0
    LSystems.maxy = 0
    LSystems.minx = 0
    LSystems.miny = 0
    position_stack = Array.new

    str.each_byte{|z|
      x = z.chr
      found = false
      if x == "[" then
        position_stack.push [@curx, @cury, @curangle]
      end
      if x == "]" then
        vals = position_stack.pop
        @curx = vals[0]
        @cury = vals[1]
        @curangle = vals[2]
      end
      LSystems.lines.each{|y|
        if x == y[0] && !found then
          result << [@curx,@cury,@curx + Math.cos(3.14159/180*@curangle) * y[1].to_f, @cury + Math.sin(3.14159/180*@curangle) * y[1].to_f]
          @curx += Math.cos(3.14159/180*@curangle) * y[1].to_f
          @cury += Math.sin(3.14159/180*@curangle) * y[1].to_f
          found = true
          break
        end
      }
      LSystems.blanks.each{|y|
        if x == y[0] && !found then
          @curx += Math.cos(3.14159/180*@curangle) * y[1].to_f
          @cury += Math.sin(3.14159/180*@curangle) * y[1].to_f
          found = true
          break
        end
      }
      LSystems.angles.each{|y|
        if x == y[0] && !found then
          @curangle += y[1].to_f
          found = true
          break
        end
      }
      if @curx > LSystems.maxx then LSystems.maxx = @curx end
      if @cury > LSystems.maxy then LSystems.maxy = @cury end
      if @curx < LSystems.minx then LSystems.minx = @curx end
      if @cury < LSystems.miny then LSystems.miny = @cury end
    }

    result2 = Array.new
    scalex = $width / (1.2 * (LSystems.maxx - LSystems.minx))
    scaley = $height / (1.2 * (LSystems.maxy - LSystems.miny))
    if scalex < scaley then
      scale = scalex
      offsetx = (LSystems.maxx - LSystems.minx) * scale * 0.1
      offsety = ($height - (LSystems.maxy - LSystems.miny) * scale) * 0.5 - LSystems.miny
    else
      scale = scaley
      offsety = (LSystems.maxy - LSystems.miny) * scale * 0.1
      offsetx = ($width - (LSystems.maxx - LSystems.minx) * scale) * 0.5 - LSystems.minx
    end

    result.each{|x|
      result2 << [(x[0] - LSystems.minx) * scale + offsetx, (x[1] - LSystems.miny) * scale + offsety, (x[2] - LSystems.minx) * scale + offsetx, (x[3] - LSystems.miny) * scale + offsety]
    }

    LSystems.box = [offsetx,offsety,(LSystems.maxx - LSystems.minx) * scale + offsetx, (LSystems.maxy - LSystems.miny) * scale + offsety]
    result2
  end

  def render(widget)
    @iterations = @entry3.text.to_i
    if verify then
      result = @axiome
      @iterations.times {
        result = treat(result)
      }
      LSystems.lines_to_draw = str2lines result

      t = Thread.new{
        require 'sdl'
        SDL.init(SDL::INIT_VIDEO)
        $screen = SDL.setVideoMode($width,$height,24,SDL::HWSURFACE | SDL::RESIZABLE)
        SDL::WM.setCaption("LinderMayer Systems GUI",
                           "LSystems")
        $white = $screen.format.mapRGB(255,255,255)

        def render
          LSystems.lines_to_draw.each{|x|
            $screen.draw_line(x[0].to_i,x[1].to_i,x[2].to_i,x[3].to_i,$white)
          }
          $screen.flip
        end

        def recompute
          result = Array.new
          scalex = $width / (1.2 * (LSystems.box[2] - LSystems.box[0]))
          scaley = $height / (1.2 * (LSystems.box[3] - LSystems.box[1]))
          if scalex < scaley then
            scale = scalex
            offsetx = (LSystems.box[2] - LSystems.box[0]) * scale * 0.1
            offsety = ($height - (LSystems.box[3] - LSystems.box[1]) * scale) * 0.5
          else
            scale = scaley
            offsety = (LSystems.box[3] - LSystems.box[1]) * scale * 0.1
            offsetx = ($width - (LSystems.box[2] - LSystems.box[0]) * scale) * 0.5
          end

          LSystems.lines_to_draw.each{|x|
            result << [(x[0] - LSystems.box[0]) * scale + offsetx, (x[1] - LSystems.box[1]) * scale + offsety, (x[2] - LSystems.box[0]) * scale + offsetx, (x[3] - LSystems.box[1]) * scale + offsety]
          }

          LSystems.lines_to_draw = result
          LSystems.lines_to_draw.each{|x|
            $screen.draw_line(x[0].to_i,x[1].to_i,x[2].to_i,x[3].to_i,$white)
          }

          LSystems.box = [offsetx,offsety,(LSystems.box[2] - LSystems.box[0]) * scale + offsetx, (LSystems.box[3] - LSystems.box[1]) * scale + offsety]
        end

        render
        event = SDL::Event2.new
        quit = false
        while !quit
          event = SDL::Event2.wait
          case (event.class.name)
          when "SDL::Event2::VideoResize"
            $screen = SDL.setVideoMode(event.w,event.h,24,SDL::SWSURFACE | SDL::RESIZABLE  | SDL::SRCALPHA)
            $width = event.w
            $height = event.h
            recompute
            render
          when "SDL::Event2::Quit"
            quit = true
          when "SDL::Event2::KeyUp"
            if (event.sym == SDL::Key::ESCAPE)
              quit = true
            end
          when SDL::Event2::Quit
            quit = true
          end
          if quit then
            print "Finished treating the event and will quit\n"
          end
        end
      }
      t.join
    end
  end

  def self.parse_options(args)
    $options = OpenStruct.new
    OptionParser.new do |opts|
      opts.banner = "Usage: lsystems.rb [options]"
      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        $options.verbose = v
      end
      opts.on("-i [N]", "--iterations [N]", Integer, "Number of iterations") do |i|
        $options.iterations = i
      end
      opts.on("-f [FILE]", "--file [FILE]", String, "File containing rules and axiom") do |f|
        $options.file = f
      end
    end.parse!(args)

    if $options.verbose then
      puts "DEBUG: $options: " + $options.inspect
    end

    if $options.iterations.nil? then
      puts "WARNING: As you did not provide the expected number of iterations, assumes you want to draw the axiom itself"
      $options.iterations = 0
    end

    if not $options.file.nil? and not $options.from_stdin.nil? then
      puts "ERROR: Rules cannot be read from both file and stdin. Please choose"
      exit
    end

    if $options.file.nil? and $options.from_stdin.nil?  then
      puts "WARNING: No rules file provided. Will try from stdin"
      $options.from_stdin = true
    end

    rules = []
    if $options.from_stdin:
      rules = $stdin.readlines
    else
      rules = File.new($options.file, "r").readlines
    end

    if rules.length == 0 then
      puts "ERROR: Could not find any rules"
      exit
    elsif $options.verbose then
      puts "DEBUG: Rules read from input (before parsing) : "
      puts rules.map{|l| "DEBUG:     " + l}
    end

    rules
  end

  def self.parse_rules(rules)
    temp_rules = rules.dup
    # Thanks Ruby for the syntax of the following line. My future self will definitely like it
    temp_rules = temp_rules.map{|l| (l.include? "#" and l[/^(.*)\#/,1] or l).strip }.find_all{|l| l.length != 0}.map{|l| l.split}
    if $options.verbose then
      puts "DEBUG: Rules after cleaning comments and white spaces"
      puts temp_rules.map{|l| "DEBUG:     " + l.inspect}
    end
  end
end

if __FILE__ == $0
  rules = LSystems.parse_options ARGV
  rules = LSystems.parse_rules rules
end
