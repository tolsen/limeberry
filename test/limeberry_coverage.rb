#!/usr/bin/ruby

# Copyright (c) 2007 Lime Spot LLC

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'optparse'
require 'net/smtp'
INDENT = 18

#Usage: ruby limeberry_coverage.rb [options]
#Produces textual output indicating the line numbers in code untested, along with blame information
#For untested lines of code, the html output also contains the name of the coder.(All html output goes to ./coverage)


class Slacker
  
  attr_writer :loc
  attr_reader :loc, :files
  def initialize name
    @files = Hash.new
    @loc = 0
    @name = name
    @name.freeze
  end

  def set_line_untested file_name,line_number
    @files[file_name] ||= Array.new
    @files[file_name] << line_number
  end

  def lines_untested file_name
    @files[file_name].size
  end

  def tested_loc
    n = 0
    @files.each_value{|file| n += file.size}
    @loc - n
  end

  def percentage_tested_loc
    loc = @loc
    loc = 1 if @loc == 0
    tested_loc.to_f/loc.to_f * 100
  end

  def file_contains? file_name,line_number
    (!@files[file_name].nil?) && (@files[file_name].include? line_number)
  end

end

#taken from rcov source
def mangle_filename(base)
  base.gsub(%r{^\w:[/\\]}, "").gsub(/\./, "_").gsub(/[\\\/]/, "-") + ".html"
end

def start_of_line line_number, slacker
  slacker = ("("+slacker+") ") unless slacker == "" 
  number_of_spaces = INDENT - (line_number + slacker).length
  number_of_spaces = 1 if number_of_spaces < 0
  "&nbsp;"*number_of_spaces + slacker + line_number
end

def format_output file
  file_list = file.split('/')
  ptr = file_list.size - 1
  while ptr > 0
    break if file_list[ptr] == "limeberry"
    ptr -= 1
  end
  file_list[ptr..-1].join('/')
end

def format_2_col(col1,col2,indent)
  spaces = indent - col1.size
  spaces = 1 if spaces < 1
  col1 + "."*spaces + col2
end

#default run
email_addresses = []
options = {:html=>"--html", :blame=>false, :mail=>false, :directory=>"coverage"}
opts = OptionParser.new
opts.banner = "Usage: limeberry_coverage [options]"
opts.on("--no-html","Does not produce HTML information"){ options[:html ] = "--no-html" }
opts.on("--blame","Generate blame statistics"){ options[:blame] = true }
opts.on("-m email_address","--mail email_address",Array, "Mail statistics to addresses(separated by comma with no spaces)"){|a| email_addresses += a; options[:mail] = true }
opts.on("-o destination_directory","--output destination_directory",String, "Specify output directory"){|d| options[:directory] = d }
opts.on("-h","--help","Show this help message"){ puts opts.to_s; exit }
opts.parse!(ARGV)

if(!options[:mail] && !options[:blame] && options[:html] != "--html")
  puts "nothing to do!"
  puts opts.to_s
  exit
end

#remove trailing '/' for directory name
options[:directory].chomp("/")


file_list = ""
unit_tests_dir = File.join(File.dirname(__FILE__), "unit")
Dir.glob("#{unit_tests_dir}#{File::SEPARATOR}*_test.rb") {|test_file| file_list += test_file + " "}

#generates coverage information for each file format:
#===========================================
#filename1.rb
#===========================================
#someline
#!! this line is uncovered
#this line is covered
#........
#===========================================
#filename2.rb
#===========================================
#....

system("rcov --text-coverage --no-color #{options[:html]} -o #{options[:directory]} "+ file_list+" > diff.dat")
#puts("rcov --text-coverage --no-color #{options[:html]} -o #{options[:directory]} "+ file_list+" > diff.dat")

#put all coders in here.
#slackers = ['', 'tolsen','cyen','gyanit','shubham','sugam','pranayjain','umangsh','nitin']
slackers = Hash.new

#all the files covered by coverage, lazy filling.
files = Array.new

#analyze the diff file.
File.open("diff.dat") do |file|

  #until the first file is encountered
  while line = file.gets
    break if line =~ /^====/
  end

  #now retrieve stats for each file
  while line 
    
    file_name = file.gets.chomp #gives us the file name
    files << file_name
    
    #generate blame information for file  
    system('svn blame ' + file_name +' > temp.out')
    file2 = File.open("temp.out")
    file.gets               #eat up next line
    line_number = 0

    while (line = file.gets) && line !~ /^====/
      line2 = file2.gets
      if !line2.nil?
        person = line2.split(" ")[1]      #blame second column is name of person
      else                                
        person = ""
        #revision = -1
      end
      
      slackers[person] ||= Slacker.new person
      #revision = line2.split(" ")[0]    #revision number is the first column
      slackers[person].loc += 1
      line_number += 1
      slackers[person].set_line_untested file_name, line_number if line =~ /^!!/
    end
    file2.close
    #this file is over here
  end

  #Blame information
  slackers.delete("")
  if options[:blame] || options[:mail]

    percentage_tested = Hash.new
    tested  = Hash.new
    msg = ""
    msg << "Coverage Information" + "\n"
    msg << "="*20  + "\n"
    msg << "PERCENTAGE TESTED"  + "\n"
    slackers.sort{|a,b|b[1].percentage_tested_loc <=> a[1].percentage_tested_loc}.each{|pair| msg << pair[0] + (" " * (INDENT - pair[0].length)) + pair[1].percentage_tested_loc.round.to_s  + "\n"}
    msg << "="*20  + "\n"
    msg << "NUMBER OF LINES TESTED"  + "\n"
    slackers.sort{|a,b|b[1].tested_loc <=> a[1].tested_loc}.each{|pair| msg << pair[0] + (" " * (INDENT - pair[0].length)) + pair[1].tested_loc.round.to_s  + "\n"}
    #slackers.each{|person| puts person + "\t" + total_code - untested_code[person]}
    #untested_code.each{|person,loc| puts person + "\t:"+loc.to_s}
    msg << "="*20  + "\n"
    msg << "\n\nFiles untested"  + "\n"
    msg << "-----------------"  + "\n"
    slackers.each{|name, slacker|
      msg << "\n"+ name + "\n" + "-"*(name.length)  + "\n" unless name == ""
      f = slacker.files.sort{|a,b|b[1].size <=> a[1].size}
      f.each{|pair| msg << format_2_col(format_output(pair[0]),slacker.lines_untested(pair[0]).to_s,55) + "\n"}
    }
    puts msg if options[:blame]
    
    if options[:mail]
      msg = "Subject: Limeberry Coverage Statistics\n" + msg
      Net::SMTP.start('localhost') {|smtp| smtp.send_message(msg,'admin@limedav.com',email_addresses)}
    end
  end
  
  #now update the html files generated to include blame information
  if(options[:html] == "--html")
    files.each do |file|
      coverage_file_name = options[:directory] + "/" + (mangle_filename file) 
      coverage_file = File.open(coverage_file_name, 'r+')
      lines = coverage_file.readlines
      re = Regexp.new '<(a name="line)(\d+)("[\s]*)(/>[\s]*\d+)'
#                           md[1]   md[2]  md[3]     md[4]
  
      lines.each do |line|
        if md = re.match(line)
          line_number = md[2]
          blame = ""
          slackers.each do |name,slacker|
            #puts file + ":" + line_number
            if(slacker.file_contains? file, line_number.to_i)
              blame = name
              break
            end
          end
          line.sub!(md[4],"\/>" + start_of_line(line_number, blame))
        end
      end
    
      #update the file in place
      coverage_file.pos = 0
      coverage_file.print lines
      coverage_file.truncate(coverage_file.pos)
      coverage_file.close
    end
  end #end files.each
end #end File.open('diff.dat')

#remove temporaries:
system('rm -rf diff.dat temp.out')
