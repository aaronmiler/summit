class AddApiTokenToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :api_token, :string
    # Backfill existing users, then enforce presence + uniqueness. has_secure_token
    # generates one on create for future users.
    User.reset_column_information
    User.find_each { |u| u.update_columns(api_token: SecureRandom.base58(24)) }
    change_column_null :users, :api_token, false
    add_index :users, :api_token, unique: true
  end

  def down
    remove_column :users, :api_token
  end
end
