class FixRefboxTables < ActiveRecord::Migration[7.0]
  def change
    unless table_exists?(:user)
      create_table :user, id: false do |t|
        t.primary_key :user_id
        t.string :user_name
        t.string :user_iconurl
        t.string :password_digest
      end
    end

    unless table_exists?(:reference)
      create_table :reference, id: false do |t|
        t.primary_key :reference_id
        t.integer :reference_user_id
        t.string :reference_url
        t.string :reference_imageurl
        t.string :reference_text
        t.string :reference_start_time
        t.string :reference_end_time
        t.string :timestamp
        t.string :reference_title
      end
    end
  end
end