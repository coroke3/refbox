class CreateReferenceShare < ActiveRecord::Migration[7.0]
  def change
    create_table :reference_share, id: false do |t|
      t.primary_key :reference_share_id
      t.integer :share_reference_id
      t.integer :share_user_id
    end
  end
end
