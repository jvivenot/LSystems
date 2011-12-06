#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'sdl'

$width = 500
$height = 500

class LSystems
  def initialize(rules = {})
    @rules = rules
    if not functional_check then
      puts "ERROR: Your L-System definition is not drawable. Aborting..."
      exit
    end
  end

  def functional_check
    error = false
    @rules[:lines].each{|l| if l[1].to_i == 0 then puts "ERROR: Invalid line length (0)" end}
    @rules[:blanks].each{|l| if l[1].to_i == 0 then puts "ERROR: Invalid blank length (0)" end}
    @rules[:angles].each{|l| if l[1].to_i == 0 then puts "ERROR: Invalid angle parameter (0)" end}
    unless drawable?(treat(@rules[:axiom]))
      puts "ERROR: Axiome is not drawable as is (even after post-treatment)"
      error = true
    end
    @rules[:rules].each {|r|
      unless drawable?(post_treat(r[1]))
        puts "ERROR: Some rule result is not drawable (event after post-treatment)"
        error = true
      end
    }
    @rules[:postrules].each {|r|
      unless drawable?(r[1])
        puts "ERROR: Some post-rule result is not drawable"
        error = true
      end
    }
    !error
  end

  def treat(str)
    temp = str
    $options.iterations.times{
      result = String.new
      temp.each_byte{|y|
        x = y.chr
        found = false
        i = 0
        until found || i == @rules[:rules].length
          if @rules[:rules][i][0] == x then
            found = true
            result << @rules[:rules][i][1]
          end
          i += 1
        end
        result << x unless found
      }
      temp = result
    }
    post_treat(temp)
  end

  def post_treat(str)
    postresult = String.new
    str.each_byte{|y|
      x = y.chr
      found = false
      i = 0
      until found || i == @rules[:postrules].length
        if @rules[:postrules][i][0] == x then
          found = true
          postresult << @rules[:postrules][i][1]
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
      @rules[:angles].each{|x|
        if x[0] == y then partial_found = true end
      }
      @rules[:lines].each{|x|
        if x[0] == y then partial_found = true end
      }
      @rules[:blanks].each{|x|
        if x[0] == y then partial_found = true end
      }
      if ["[","]"].include? y then partial_found = true end
      found &&= partial_found
    }
    found
  end

  def str2lines(str)
    result = Array.new
    @curx = 0
    @cury = 0
    @curangle = 0
    @maxx = 0
    @maxy = 0
    @minx = 0
    @miny = 0
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
      @rules[:lines].each{|y|
        if x == y[0] && !found then
          result << [@curx,@cury,@curx + Math.cos(3.14159/180*@curangle) * y[1].to_f, @cury + Math.sin(3.14159/180*@curangle) * y[1].to_f]
          @curx += Math.cos(3.14159/180*@curangle) * y[1].to_f
          @cury += Math.sin(3.14159/180*@curangle) * y[1].to_f
          found = true
          break
        end
      }
      @rules[:blanks].each{|y|
        if x == y[0] && !found then
          @curx += Math.cos(3.14159/180*@curangle) * y[1].to_f
          @cury += Math.sin(3.14159/180*@curangle) * y[1].to_f
          found = true
          break
        end
      }
      @rules[:angles].each{|y|
        if x == y[0] && !found then
          @curangle += y[1].to_f
          found = true
          break
        end
      }
      if @curx > @maxx then @maxx = @curx end
      if @cury > @maxy then @maxy = @cury end
      if @curx < @minx then @minx = @curx end
      if @cury < @miny then @miny = @cury end
    }

    result2 = Array.new
    scalex = $width / (1.2 * (@maxx - @minx))
    scaley = $height / (1.2 * (@maxy - @miny))
    if scalex < scaley then
      scale = scalex
      offsetx = (@maxx - @minx) * scale * 0.1
      offsety = ($height - (@maxy - @miny) * scale) * 0.5 - @miny
    else
      scale = scaley
      offsety = (@maxy - @miny) * scale * 0.1
      offsetx = ($width - (@maxx - @minx) * scale) * 0.5 - @minx
    end

    result.each{|x|
      result2 << [(x[0] - @minx) * scale + offsetx, (x[1] - @miny) * scale + offsety, (x[2] - @minx) * scale + offsetx, (x[3] - @miny) * scale + offsety]
    }

    @box = [offsetx,offsety,(@maxx - @minx) * scale + offsetx, (@maxy - @miny) * scale + offsety]
    result2
  end

  def render
    result = @rules[:axiom]
    result = treat(result)
    if $options.verbose then puts "DEBUG: String output : %s" % result end
    @lines_to_draw = str2lines result

    $white = $screen.format.mapRGB(255,255,255)

    def subrender
      @lines_to_draw.each{|x|
        $screen.draw_line(x[0].to_i,x[1].to_i,x[2].to_i,x[3].to_i,$white)
      }
      $screen.flip
    end

    def recompute
      result = Array.new
      scalex = $width / (1.2 * (@box[2] - @box[0]))
      scaley = $height / (1.2 * (@box[3] - @box[1]))
      if scalex < scaley then
        scale = scalex
        offsetx = (@box[2] - @box[0]) * scale * 0.1
        offsety = ($height - (@box[3] - @box[1]) * scale) * 0.5
      else
        scale = scaley
        offsety = (@box[3] - @box[1]) * scale * 0.1
        offsetx = ($width - (@box[2] - @box[0]) * scale) * 0.5
      end

      @lines_to_draw.each{|x|
        result << [(x[0] - @box[0]) * scale + offsetx, (x[1] - @box[1]) * scale + offsety, (x[2] - @box[0]) * scale + offsetx, (x[3] - @box[1]) * scale + offsety]
      }

      @lines_to_draw = result
      @lines_to_draw.each{|x|
        $screen.draw_line(x[0].to_i,x[1].to_i,x[2].to_i,x[3].to_i,$white)
      }

      @box = [offsetx,offsety,(@box[2] - @box[0]) * scale + offsetx, (@box[3] - @box[1]) * scale + offsety]
    end

    subrender
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
        subrender
      when "SDL::Event2::Quit"
        quit = true
      when "SDL::Event2::KeyUp"
        if (event.sym == SDL::Key::ESCAPE)
          quit = true
        end
      when SDL::Event2::Quit
        quit = true
      end
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
    begin
      look_for = lambda {|item| temp_rules.find_all{|x| x[0] == item}}
      rules_dict = {
        :axiom     => look_for.call("axiom"),
        :rules     => look_for.call("rule"),
        :postrules => look_for.call("postrule"),
        :lines     => look_for.call("line"),
        :angles    => look_for.call("angle"),
        :blanks    => look_for.call("blank"),
      }
      temp_rules -= rules_dict.inject([]){|s,v| s+= v[1]}
      if temp_rules.length != 0 then
        puts "ERROR: The following lines could not be parsed :"
        temp_rules.each{|l| puts "ERROR:   %s\n" % l.inspect}
        exit
      end
      if $options.verbose then puts "DEBUG: Created rule dictionary" end
      rules_dict = Hash[rules_dict.map{|k,v| [k,v.map{|l| l[1..l.length-1]}]}]
      if $options.verbose then puts "DEBUG: Creaned keywords" end
      if rules_dict[:axiom].length != 1 or rules_dict[:axiom][0].length != 1 then
        puts "ERROR: Please provide one and only one axiom. (Syntax: 'axiom AB--B')"
        exit
      else
        rules_dict[:axiom] = rules_dict[:axiom][0][0]
      end
      if $options.verbose then puts "DEBUG: Verifying all rules (except axiom) are defined correctly" end
      rules_dict.each{|k,v|
        if k != :axiom and not v.inject(true){|r,x| r and (x.length==2)} then
          puts "ERROR: One of the rules (within '%s') is not defined completely. Please check" % k
          exit
        end
      }
    rescue
      puts "ERROR: Something went wrong with the syntax. Please be more careful"
      raise
    end
    if $options.verbose then
      puts "DEBUG: Rules dictionary after parsing"
      rules_dict.each{|k,v| puts "DEBUG:     %-7s => %s" % [k,v.inspect]}
    end
    rules_dict
  end
end

if __FILE__ == $0
  rules = LSystems.parse_options ARGV
  rules = LSystems.parse_rules rules
  instance = LSystems.new(rules)
  SDL.init SDL::INIT_VIDEO
  $screen = SDL.setVideoMode($width,$height,24,SDL::HWSURFACE | SDL::RESIZABLE)
  SDL::WM.setCaption("LinderMayer Systems GUI", "LSystems")
  instance.render
end
