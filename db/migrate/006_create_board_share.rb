class CreateBoardShare < ActiveRecord::Migration[7.0]
  def change
    create_table :board_share, id: false do |t|
      t.primary_key :board_share_id
      t.integer :share_board_id
      t.integer :share_user_id
    end
  end
end
