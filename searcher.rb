# Multiple Input Multiple Output searcher by Nick DelBen
require('pathname')
require('./utils.rb')

# A file location for searching
class SearchFile
    # Create a new file for searching
    def initialize(file_path)
        @path = Pathname.new(file_path)
        @open = false
        @file = nil
    end
    # Close the file
    def close()
        if @open
            @file.close
        end
        @open = false
        @file = nil
    end
end

# A destination to store search results
class SearchDestination < SearchFile
    @@default_write_mode = 'a'
    @@write_delimiter = ':'

    # Create a new search destination
    def initialize(destination_path)
        super(destination_path)
        @write_mode = @@default_write_mode
        # Ensure the parent directory of this path is valid
        raise InvalidPath unless Pathname.new(@path.dirname).directory?
        # Ensure the destination path is not a directory
        raise InvalidPath if @path.directory?
        # Does user want to overwrite or append to file
        if @path.file?
            case get_input("Destination file path '" + destination_path + "' exists would you like to (O)verwrite the file (A)ppend to the file or (C)ancel: ", ['o','a','c'])
            when 'o'
                @write_mode = 'w'
            when 'a'
                @write_mode = 'a'
            else
                raise UserTerminated
            end
        end
    end
    # Write a line to the file
    def write(string, write_file=false)
        # Check if currently writing to this file
        if @open == false
            # Open the file for writing
            @file = File.new(@path.to_s, @write_mode)
            @open = true
            # Only write the first time, append afterwords
            @write_mode =  @@default_write_mode if @write_mode.downcase == 'w'
        end
        # Write line to file
        if write_file
            @file.puts(@path.basename + @@write_delimiter + string)
        else
            @file.puts(string)
        end
    end
end

# A location to read search results from
class SearchSource < SearchFile
    @@default_read_mode = 'r'

    # Create a new search source
    def initialize(source_path)
        super(source_path)
        # Check if the source path exists
        throw InvalidPath if !@path.exist?
        # Check if the source path is a directory
        throw InvalidPath if !@path.file?
    end
    # Opens the file for searching
    def open
        # Check if the file is open
        return false if @open
        @open = true
        # Open the file for reading
        @file = File.new(@path.to_s, @@default_read_mode)
    end
    # Checks if this file has lines to read
    def has_line
        open
        return !@file.eof
    end
    # Read and return the next line from the source file
    def readline
        open
        # Check if there are any lines left to read
        throw FileEOF if !has_line
        return @file.readline
    end
end

# Multiple Input Multiple Output searcher
class MIMOSearcher
    # Create a new instance of Searcher
    def initialize(show_file=false)
        # Store the path to the destination file
        @show_file = show_file
        @queries = []
        @path_sources = []
        @destinations = []
        @source_index = 0
        @current_source = nil
        @line = nil
    end
    # Adds all files from an directory optionally matching the specified pattern
    def add_directory(directory_path, search_pattern=/.*/)
        Dir.entries(directory_path).each do |file_path|
            # Ensure the result is a file
            next unless file_path[search_pattern]
            # Add file as input if path is valid file
            add_source(file_path) if SearchDestination.new(directory_path).file?
        end
    end
    # Adds a regular expression query to search the lines for
    def add_regex(*queries)
        queries.each do |query|
            # Change the specified query into a regular expression object
            begin
                query = Regexp.new(query)
            rescue RegexpError
                next
            end
            # Add the query to the list of queries
            @queries.push(query)
        end
    end
    # Adds a query to search the lines for
    def add_query(*queries)
        queries.each do |query|
            # Add the query to the list of queries
            @queries.push(query)
        end
    end
    # Add a new destination document to write the results to
    def add_destination(*destination_paths)
        destination_paths.each do |destination|
            begin
                # Create a new destination for this path
                new_destination = SearchDestination.new(destination)
            rescue InvalidPath
                next
            rescue UserTerminated
                next
            end
            # Add destination to list of sources
            @destinations.push(new_destination)
        end
    end
    # Checks if there are any unloaded sources
    def has_source
        return @path_sources.length > @source_index
    end
    # Load the next source
    def next_source
        if !@current_source == nil
            @current_source.close
        end
        if !has_source
            raise NoSource
        end
        @current_source = @path_sources[@source_index]
        @source_index += 1
    end
    # Add a new source document (can specify multiple documents)
    def add_source(*source_paths)
        source_paths.each do |source|
            begin
                # Create a new source for this path
                new_source = SearchSource.new(source)
            rescue InvalidPath
                #logger.info("Source file '" + source + "' not added.")
            end
            # Add the source to the list of sources
            @path_sources.push(new_source)
            #logger.info("Added source: " + source)
        end
    end
    # Check if there is a line to read
    def has_line
        # Check if there is currently a source
        if @current_source == nil
            return false if !has_source
            next_source
        end
        # Check if the current source has any lines left
        if !@current_source.has_line
            @current_source.close
            @current_source = nil
            return has_line
        end
        return true
    end
    # Write to the output files
    def write(string)
        @destinations.each do |destination|
            destination.write(string, @show_file)
        end
    end
    # Set and return the next line for reading
    def readline
        if !has_line
            raise NoSource
        end
        @line = @current_source.readline
        return @line
    end
    # Search files for matches
    def file_search
        results = []
        # Check if there are still sources to search
        return results if !has_source && @current_file == nil
        next_source if current_file == nil
        while has_line:
            # Read the next line from the source files
            line = readline
            # Check if the line matches any queries
            @queries.each do |query|
                next unless line[query]
                # Store the file the expression was found in to the results list
                results.push(@current_file.path.to_s)
                @current_file.close
                @current_file = nil
                break
            end
        end
        return results
    end
    # Search linesz in files for a matcg
    def line_search(write_results=true)
        while has_line
            readline
            @queries.each do |query|
                if @line[query]
                    write(@line) if write_results
                end
            end
        end
    end
    # Close and remove any specified inputs
    def clear_inputs
        # Close any open input file
        if @current_file ~= nil
            @current_file.close
            @current_file = nil
        end
        @path_sources.clear
    end
    # Close all open destination files
    def close
        # Close any open input file
        @current_file.close if @current_file ~= nil
        # Close any output file
        @destinations.each do |destination|
            destination.close
        end
    end
end
