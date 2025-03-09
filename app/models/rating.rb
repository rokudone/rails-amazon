class Rating < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :product

  # バリデーション
  validates :value, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :user_id, uniqueness: { scope: [:product_id, :dimension], message: "すでにこの商品の評価を投稿しています" }
  validates :dimension, presence: true, if: -> { !dimension.nil? }

  # コールバック
  after_save :update_product_rating, if: -> { saved_change_to_value? }
  after_destroy :update_product_rating

  # スコープ
  scope :by_dimension, ->(dimension) { where(dimension: dimension) }
  scope :by_value, ->(value) { where(value: value) }
  scope :by_value_range, ->(min, max) { where('value >= ? AND value <= ?', min, max) }
  scope :anonymous, -> { where(is_anonymous: true) }
  scope :recent, -> { order(created_at: :desc) }

  # クラスメソッド
  def self.average_by_dimension(dimension)
    where(dimension: dimension).average(:value).to_f.round(1)
  end

  def self.distribution_by_dimension(dimension)
    where(dimension: dimension).group(:value).count
  end

  def self.dimensions_for_product(product_id)
    where(product_id: product_id).pluck(:dimension).uniq
  end

  # カスタムメソッド
  def anonymous!
    update(is_anonymous: true)
  end

  def identified!
    update(is_anonymous: false)
  end

  private

  def update_product_rating
    product.update_average_rating if product.present?
  end
end
