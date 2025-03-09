class ProductDescription < ApplicationRecord
  # 関連付け
  belongs_to :product

  # バリデーション
  validates :full_description, presence: true

  # カスタムメソッド
  def html_description
    # 仮定: Markdownからの変換ロジックが後で実装される
    full_description
  end

  def short_description
    # 仮定: 短い説明を生成するロジックが後で実装される
    full_description.truncate(200, separator: ' ')
  end

  def has_features?
    features.present?
  end

  def has_care_instructions?
    care_instructions.present?
  end

  def has_warranty_info?
    warranty_info.present?
  end

  def has_return_policy?
    return_policy.present?
  end

  def features_list
    return [] unless features.present?
    features.split("\n").map(&:strip).reject(&:empty?)
  end

  def care_instructions_list
    return [] unless care_instructions.present?
    care_instructions.split("\n").map(&:strip).reject(&:empty?)
  end
end
