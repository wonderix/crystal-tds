require "./spec_helper"
require "big"

describe DB::Transaction do
  it "commit is working" do
    DB.open URL do |db|
      db.transaction do |tx|
        cnn = tx.connection
      end
    end
  end
  it "rollback is working" do
    DB.open URL do |db|
      db.transaction do |tx|
        cnn = tx.connection
        tx.rollback
      end
    end
  end
end
