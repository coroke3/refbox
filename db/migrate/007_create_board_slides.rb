class CreateBoardSlides < ActiveRecord::Migration[7.0]
  def up
    create_table :board_slides do |t|
      t.integer :board_id, null: false
      t.integer :position, null: false
      t.text :content, null: false, default: '{"refs":[],"notes":[],"strokes":[]}'
    end
    add_index :board_slides, [:board_id, :position]

    connection.select_all('SELECT board_id FROM board').each do |board|
      scenes = connection.select_all("SELECT relate_board_reference_id, ralate_borad_text FROM boardrelate WHERE relate_board_id = #{board['board_id'].to_i} ORDER BY relate_board_position, boardrelate_id")
      scenes = [nil] if scenes.empty?
      scenes.each_with_index do |scene, index|
        refs = scene ? [{ id: scene['relate_board_reference_id'].to_i, x: 20, y: 18, w: 55 }] : []
        note = scene && scene['ralate_borad_text'].to_s.strip
        notes = note.to_s.empty? ? [] : [{ id: "old-#{index}", text: note, x: 58, y: 45, w: 28 }]
        content = { refs: refs, notes: notes, strokes: [] }.to_json
        execute "INSERT INTO board_slides (board_id, position, content) VALUES (#{board['board_id'].to_i}, #{index + 1}, #{connection.quote(content)})"
      end
    end
  end

  def down
    drop_table :board_slides
  end
end
