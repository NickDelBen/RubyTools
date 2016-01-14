# Multiple Input Multiple Output file copier by Nick DelBen
require('pathname')
require('fileutils')
require('./utils.rb')

def copy_file(source, destination)
    write_mode = 'w'
    # Check if a file already exists with the specified path
    if destination.file?
        # Check how to handle the file conflict
        case get_input("Destination path '" + destination.to_s + "' already exists. (O)verwrite the file, (S)kip the file, or (C)ancel: ", ['o','s','c'])
        when 'o'
            write_mode = 'w'
        when 's'
            return true
        else
            return false
        end
    end
    # Preform the file copy
    FileUtils.cp(source.to_s, destination.to_s)
    return true
end

# Multiple Input Multiple Output file copier
class MIMOCopier
    def initialize
        @sources = []
        @destination_files = []
        @destination_directories = []
    end
    # Add a source file to be copied
    def add_source(*source_paths)
        source_paths.each do |source|
            new_path = Pathname.new(source)
            # Check if the source path is a directory
            next unless new_path.file?
            # Add the new source to the list of source file paths
            @sources.push(new_path)
        end
    end
    # Add a destination and automatically assign its type
    def add_destination(*destination_paths)
        destination_paths.each do |destination|
            new_path = Pathname.new(destination)
            # Check if the specified path is a directory
            if new_path.directory?
                @destination_directories.push(new_path)
                next
            end
            # Check to ensure the parent directory is valid
            return false unless Pathname.new(new_path.dirname).directory?
            @destination_files.push(new_path)
        end
        return true
    end
    # Add a destination directory to copy the file to
    def add_destination_file(*destination_files)
        destination_files.each do |destination|
            new_path = Pathname.new(destination)
            # Check to ensure the specified path is a directory
            next if new_path.directory?
            # Add the new destination to the list of destination directories
            @destination_files.push(new_path)
        end
    end
    # Add a destination directory to copy the file to
    def add_destination_directory(*destination_paths)
        destination_paths.each do |destination|
            new_path = Pathname.new(destination)
            # Check to ensure the specified path is a directory
            next unless new_path.directory?
            # Add the new destination to the list of destination directories
            @destination_directories.push(new_path)
        end
    end
    # Copies the first source file to all the destination files
    def preform_copy_file
        @destination_files.each do |destination|
            copy_file(@sources.pop, destination)
        end
    end
    # Copies all the source files to the specified directories
    def preform_copy_directory
        @destination_directories.each do |destination|
            @sources.each do |source|
                write_mode = 'w'
                new_path = Pathname.new(destination.to_s).join(source.basename)
                # Check if the specified file is a directory
                if new_path.directory?
                    return false if get_input("Destination path '" + new_path.to_s + "' is a directory. (S)kip the file or (C)ancel: ", ['s','c']) == 'c'
                    next
                end
                # Copy the file
                return false unless copy_file(source, new_path)
            end
        end
        return true
    end
    # Preform all copies
    def preform_copy
        preform_copy_file
        preform_copy_directory
    end
end
