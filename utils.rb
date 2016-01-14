class InvalidPath < Exception
end
class UserTerminated < Exception
end
class FileEOF < Exception
end
class NoSource < Exception
end

# Gets the response of a choice question from the user
def get_input(message, choices)
    print(message)
    response = gets.chomp.downcase
    while response.length < 1 || !choices.include?(response[0])
        print("Invalid selection. " + message)
        response = gets.chomp.downcase
    end
    return response[0]
end
