# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# The two users. Identity is a picker, not auth (see docs/data_model.md). The
# Library ships empty; these are Context, and the picker needs someone to pick.
%w[Aaron Bree].each { |name| User.find_or_create_by!(name: name) }
