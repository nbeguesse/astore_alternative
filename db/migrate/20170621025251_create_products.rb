class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :asin
      t.text :xml
      t.date :expires_at

      t.timestamps
    end
  end
end
