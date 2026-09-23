class CreateBoardrelate < ActiveRecord::Migration[7.0]
  def change
    create_table :boardrelate, id: false do |t|
      t.primary_key :boardrelate_id
      t.integer :relate_board_id
      t.integer :relate_board_reference_id
      t.string :ralate_borad_text
      t.integer :relate_board_position
    end
  end
end
