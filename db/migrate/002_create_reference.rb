class CreateReference < ActiveRecord::Migration[7.0]
  def change
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
