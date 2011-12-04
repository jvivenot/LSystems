#!/usr/bin/env ruby

require 'libglade2'

Axiome = "Axiome"
Regle = "Regle"
Regle2 = "Post Regle"
Line = "Ligne"
Blank = "Blank"
Angle = "Angle"

$width = 500
$height = 500

class RlsystemGlade
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

    [[Axiome,"F++F++F",""],
     [Regle, "F", "F-F++F-F"],
     [Line,"F","1"],
     [Angle,"+","60"],
     [Angle,"-","-60"]
    ].each {|x|
      iter = @liststore.append
      @liststore.set_value(iter,0,x[0])
      @liststore.set_value(iter,1,x[1])
      @liststore.set_value(iter,2,x[2])
    }

    @entry3.text = "5"

  end

  class Arbre

    attr :val,:sons
    @sons = Array.new
    def new(val,sons)
      @val = val
      sons.each {|x| @sons << x}
    end

    def add_son(s)
      @sons << s
    end

    def tree2lines(x,y,angle)
      arr = Array.new
      curx = x
      cury = y
      curangle = angle

      if !@val.nil? then
        found = false
        @@lines.each{|y|
          if @val == y[0] && !found then
            arr << [curx,cury,curx + Math.cos(3.14159/180*curangle) * y[1].to_f, cury + Math.sin(3.14159/180*curangle) * y[1].to_f]
            curx += Math.cos(3.14159/180*curangle) * y[1].to_f
            cury += Math.sin(3.14159/180*curangle) * y[1].to_f
            found = true
            break
          end
        }
        @@blanks.each{|y|
          if @val == y[0] && !found then
            curx += Math.cos(3.14159/180*curangle) * y[1].to_f
            cury += Math.sin(3.14159/180*curangle) * y[1].to_f
            found = true
            break
          end
        }
        @@angles.each{|y|
          if @val == y[0] && !found then
            curangle += y[1].to_f
            found = true
            break
          end
        }
      end

      if @sons.length != 0 then
        @sons.each {|t| arr << t.tree2lines(curx,cury,curangle)}
      end

      if curx > @@maxx then @@maxx = curx end
      if cury > @@maxy then @@maxy = cury end
      if curx < @@minx then @@minx = curx end
      if cury < @@miny then @@miny = cury end

      arr
    end
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
      @@angles.each{|x|
        if x[0] == y then partial_found = true end
      }
      @@lines.each{|x|
        if x[0] == y then partial_found = true end
      }
      @@blanks.each{|x|
        if x[0] == y then partial_found = true end
      }
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
        @@lines << [iter[1],iter[2]]
      when Blank
        if iter[2].to_i == 0 then
          message "Erreur : Parametre secondaire de blanc invalide"
          error = true
        end
        @@blanks << [iter[1],iter[2]]
      when Angle
        if iter[2].to_i == 0 then
          message "Erreur : Parametre secondaire d'angle invalide"
          error = true
        end
        @@angles << [iter[1],iter[2]]
      end
    }

    unless drawable?(treat(@axiome))
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
    @@lines = Array.new
    @@blanks = Array.new
    @@angles = Array.new
  end

  def str2lines(str)
    result = Array.new
    @curangle = 0
    @curx = 0
    @cury = 0
    @@maxx = 0
    @@maxy = 0
    @@minx = 0
    @@miny = 0

     str.each_byte{|z|
       x = z.chr
       found = false
       @@lines.each{|y|
         if x == y[0] && !found then
           result << [@curx,@cury,@curx + Math.cos(3.14159/180*@curangle) * y[1].to_f, @cury + Math.sin(3.14159/180*@curangle) * y[1].to_f]
           @curx += Math.cos(3.14159/180*@curangle) * y[1].to_f
           @cury += Math.sin(3.14159/180*@curangle) * y[1].to_f
           found = true
           break
         end
       }
       @@blanks.each{|y|
         if x == y[0] && !found then
           @curx += Math.cos(3.14159/180*@curangle) * y[1].to_f
           @cury += Math.sin(3.14159/180*@curangle) * y[1].to_f
           found = true
           break
         end
       }
       @@angles.each{|y|
         if x == y[0] && !found then
           @curangle += y[1].to_f
           found = true
           break
         end
       }
       if @curx > @@maxx then @@maxx = @curx end
       if @cury > @@maxy then @@maxy = @cury end
       if @curx < @@minx then @@minx = @curx end
       if @cury < @@miny then @@miny = @cury end
     }


#    def str2tree(str)
#      if str == "" then nil else
#        case str[0]
#        when "["
#          par = 1
#          i = 1
#          while par != 0
#            case str[i]
#            when "["
#              par += 1
#            when "]"
#              par -= 1
#            end
#            i += 1
#          end
#          Arbre.new(nil,[str2tree(str[1..i-2]),str2tree(str[i..-1])])
#        else
#          str.length == 1 ? Arbre.new(str[0],[]) : Arbre.new(str[0],[str2tree(str[1..-1])])
#        end
#      end
#    end
#    result - str2tree(str)

    result2 = Array.new
    scalex = $width / (1.2 * (@@maxx - @@minx))
    scaley = $height / (1.2 * (@@maxy - @@miny))
    if scalex < scaley then
      scale = scalex
      offsetx = (@@maxx - @@minx) * scale * 0.1
      offsety = ($height - (@@maxy - @@miny) * scale) * 0.5 - @@miny
    else
      scale = scaley
      offsety = (@@maxy - @@miny) * scale * 0.1
      offsetx = ($width - (@@maxx - @@minx) * scale) * 0.5 - @@minx
    end

    result.each{|x|
      result2 << [(x[0] - @@minx) * scale + offsetx, (x[1] - @@miny) * scale + offsety, (x[2] - @@minx) * scale + offsetx, (x[3] - @@miny) * scale + offsety]
    }

    @@box = [offsetx,offsety,(@@maxx - @@minx) * scale + offsetx, (@@maxy - @@miny) * scale + offsety]
    result2
  end

  def render(widget)
    @iterations = @entry3.text.to_i
    if verify then
      result = @axiome
      @iterations.times {
        result = treat(result)
      }
      @@result2 = str2lines result

      t = Thread.new{
        require 'sdl'
        SDL.init(SDL::INIT_VIDEO)
        $screen = SDL.setVideoMode($width,$height,24,SDL::HWSURFACE | SDL::RESIZABLE)
        SDL::WM.setCaption("LinderMayer Systems GUI",
                           "LSystems")
        $white = $screen.format.mapRGB(255,255,255)

        def render
          @@result2.each{|x|
            $screen.draw_line(x[0].to_i,x[1].to_i,x[2].to_i,x[3].to_i,$white)
          }
          $screen.flip
        end

        def recompute
          result = Array.new
          scalex = $width / (1.2 * (@@box[2] - @@box[0]))
          scaley = $height / (1.2 * (@@box[3] - @@box[1]))
          if scalex < scaley then
            scale = scalex
            offsetx = (@@box[2] - @@box[0]) * scale * 0.1
            offsety = ($height - (@@box[3] - @@box[1]) * scale) * 0.5
          else
            scale = scaley
            offsety = (@@box[3] - @@box[1]) * scale * 0.1
            offsetx = ($width - (@@box[2] - @@box[0]) * scale) * 0.5
          end

          @@result2.each{|x|
            result << [(x[0] - @@box[0]) * scale + offsetx, (x[1] - @@box[1]) * scale + offsety, (x[2] - @@box[0]) * scale + offsetx, (x[3] - @@box[1]) * scale + offsety]
          }

          @@result2 = result
          @@result2.each{|x|
            $screen.draw_line(x[0].to_i,x[1].to_i,x[2].to_i,x[3].to_i,$white)
          }

          @@box = [offsetx,offsety,(@@box[2] - @@box[0]) * scale + offsetx, (@@box[3] - @@box[1]) * scale + offsety]
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
end

if __FILE__ == $0
  PROG_PATH = "rlsystem.glade"
  PROG_NAME = "LSystems"
  Gtk.init
  RlsystemGlade.new(PROG_PATH, nil, PROG_NAME)
  Gtk.main
end

