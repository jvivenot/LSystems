#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'sdl'

$width = 500
$height = 500

def ERROR(str)
  puts "ERROR: %s" % str
  true
end
def WARNING(str)
  puts "WARNING: %s" % str
  true
end
def DEBUG(str)
  puts "DEBUG: %s" % str
  true
end

class LSystems
  def initialize(rules)
    @rules = rules
    @drawable_chars = @rules[:lines].keys + @rules[:blanks].keys + @rules[:angles].keys + ['[',']']
    DEBUG "Drawable characters : %s" % @drawable_chars.inspect if $options.verbose
    ERROR "Your L-System definition is not drawable. Aborting..." and exit unless functional_check
  end

  def functional_check
    error = false
    for key in [:lines, :blanks, :angles]
      @rules[key].each{|k,v| if (key == :lines and v[0] or v).to_i == 0 then error ||= ERROR "Invalid %s length (0)" % key.to_s.chomp("s") end}
    end
    unless drawable?(treat(@rules[:axiom]))
      error ||= ERROR "Axiom isn't drawable (even after post-treatment)"
    end
    unless @rules[:rules].find_all {|r| not drawable?(post_treat(r[1]))}.length == 0
      error ||= ERROR "Some rule result is not drawable (event after post-treatment)"
    end
    unless @rules[:postrules].find_all {|r| not drawable?(r[1])}.length == 0
      error ||= ERROR "Some post-rule result is not drawable"
    end
    !error
  end

  def reduct(str)
    #For now, only take care of unnecessary push/pop in the stack
    str.gsub!(/\[\]/,'') while str.include? "[]"
    str
  end

  def __treat(str,rules,post=false)
    temp = str
    $options.iterations.times{
      result = ""
      temp.each_char{|c| result << (rules.keys.include? c and rules[c] or c) }
      temp = result
    }
    reduct((post and temp or post_treat(temp)))
  end

  def treat(str)
    __treat(str,@rules[:rules])
  end

  def post_treat(str)
    __treat(str,@rules[:postrules],post=true)
  end

  def drawable?(str)
    str.split(//).inject(true){|result,char| result and (@drawable_chars.include? char)}
  end

  def str2lines(str)
    result = []
    @curx,@cury,@curangle = 0,0,0
    @minx,@maxx,@miny,@maxy = 0,0,0,0
    position_stack = []

    str.each_char{|x|
      if x == "[" then
        position_stack.push [@curx, @cury, @curangle]
      elsif x == "]" then
        vals = position_stack.pop
        @curx = vals[0]
        @cury = vals[1]
        @curangle = vals[2]
      elsif @rules[:lines].keys.include? x then
        length = @rules[:lines][x][0].to_f
        result << [@curx,@cury,@curx + Math.cos(3.14159/180*@curangle) * length, @cury + Math.sin(3.14159/180*@curangle) * length]
        @curx += Math.cos(3.14159/180*@curangle) * length
        @cury += Math.sin(3.14159/180*@curangle) * length
      elsif @rules[:blanks].keys.include? x then
        length = @rules[:blanks][x].to_f
        @curx += Math.cos(3.14159/180*@curangle) * length
        @cury += Math.sin(3.14159/180*@curangle) * length
      elsif @rules[:angles].keys.include? x then
        @curangle += @rules[:angles][x].to_f
      else
        ERROR "How did I get here ? Got to an undrawable character : '%s'" % x and exit
      end
      @maxx = [@curx,@maxx].max
      @maxy = [@cury,@maxy].max
      @minx = [@curx,@minx].min
      @miny = [@cury,@miny].min
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
    result = treat(@rules[:axiom])
    DEBUG "Complete drawing string output : %s" % result if $options.verbose
    @lines_to_draw = str2lines result
    $white = $screen.format.mapRGB(255,255,255)

    def subrender
      @lines_to_draw.each{|x|
        $screen.draw_line(x[0].to_i,x[1].to_i,x[2].to_i,x[3].to_i,$white)
      }
      $screen.flip
    end

    def recompute
      result = []
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

      @lines_to_draw.map!{|x|
        [(x[0] - @box[0]) * scale + offsetx, (x[1] - @box[1]) * scale + offsety, (x[2] - @box[0]) * scale + offsetx, (x[3] - @box[1]) * scale + offsety]
      }
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
      when "SDL::Event2::KeyUp"
        quit = (event.sym == SDL::Key::ESCAPE)
      when "SDL::Event2::Quit"
        quit = true
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

    DEBUG "options: " + $options.inspect if $options.verbose

    if $options.iterations.nil? then
      WARNING "No number of iterations provided, assuming you want to draw the axiom itself"
      $options.iterations = 0
    end

    if not $options.file.nil? and not $options.from_stdin.nil? then
      ERROR "Rules cannot be read from both file and stdin. Please choose"
      exit
    end

    if $options.file.nil? and $options.from_stdin.nil?  then
      WARNING "No rules file provided. Will try from stdin"
      $options.from_stdin = true
    end

    rules = []
    if $options.from_stdin:
      rules = $stdin.readlines
    else
      rules = File.new($options.file, "r").readlines
    end

    if rules.length == 0 then
      ERROR "Could not find any rules"
      exit
    elsif $options.verbose then
      DEBUG "Rules read from input (before parsing) : "
      rules.map{|l| DEBUG "     " + l}
    end

    rules
  end

  def self.parse_rules(rules)
    temp_rules = rules.dup
    # Thanks Ruby for the syntax of the following line. My future self will definitely like it
    temp_rules = temp_rules.map{|l| (l.include? "#" and l[/^(.*)\#/,1] or l).strip }.find_all{|l| l.length != 0}.map{|l| l.split}
      if $options.verbose then
        DEBUG "Rules after cleaning comments and white spaces"
        temp_rules.each{|l| DEBUG "     " + l.inspect}
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
        ERROR "The following lines could not be parsed :"
        temp_rules.each{|l| ERROR "   %s" % l.inspect}
        exit
      end
      DEBUG "Created rule dictionary" if $options.verbose
      rules_dict = Hash[rules_dict.map{|k,v| [k,v.map{|l| l[1..l.length-1]}]}]
      DEBUG "Cleaned keywords" if $options.verbose
      if rules_dict[:axiom].length != 1 or rules_dict[:axiom][0].length != 1 then
        ERROR "Please provide one and only one axiom. (Syntax: 'axiom AB--B')" and exit
      else
        rules_dict[:axiom] = rules_dict[:axiom][0][0]
      end
      DEBUG "Verifying all rules (except axiom) are defined correctly" if $options.verbose
      rules_dict.each{|k,v|
        if k != :axiom and not v.inject(true){|r,x| r and x.length==2} then
          ERROR "One of the rules (within '%s') is not defined completely. Please check" % k
          exit
        end
      }
      DEBUG "Making dictionaries out of rules, postrules, etc" if $options.verbose
      [:rules,:postrules,:angles,:blanks].each{|k| rules_dict[k] = Hash[rules_dict[k]] }
      rules_dict[:lines] = Hash[rules_dict[:lines].map{|l|  [l[0], l[1..l.length-1]]}]
    rescue
      ERROR "Something went wrong with the syntax. Please be more careful"
      raise
    end
    if $options.verbose then
      DEBUG "Rules dictionary after parsing"
      rules_dict.each{|k,v| DEBUG "     %-7s => %s" % [k,v.inspect]}
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
