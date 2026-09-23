class CreateBoard < ActiveRecord::Migration[7.0]
  def change
    create_table :board, id: false do |t|
      t.primary_key :board_id
      t.integer :board_user_id
      t.string :board_name
      t.boolean :board_is_public
      t.datetime :timestamp
    end
  end
end
