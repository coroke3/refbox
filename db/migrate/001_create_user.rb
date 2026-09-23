class CreateUser < ActiveRecord::Migration[7.0]
  def change
    create_table :user, id: false do |t|
      t.primary_key :user_id
      t.string :user_name
      t.string :user_iconurl
      t.string :password_digest
    end
  end
end
