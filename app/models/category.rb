class Category < ApplicationRecord
  # 関連付け
  belongs_to :parent, class_name: 'Category', optional: true
  has_many :children, class_name: 'Category', foreign_key: 'parent_id', dependent: :destroy

  has_many :sub_categories, dependent: :destroy
  has_many :products, dependent: :nullify

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 255 },
            format: { with: /\A[a-z0-9\-_]+\z/, message: "は小文字英数字、ハイフン、アンダースコアのみ使用できます" }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :root_categories, -> { where(parent_id: nil) }
  scope :ordered, -> { order(position: :asc) }

  # 階層構造の実装
  def ancestors
    result = []
    current = self
    while current.parent
      result << current.parent
      current = current.parent
    end
    result.reverse
  end

  def descendants
    result = []
    queue = children.to_a
    until queue.empty?
      current = queue.shift
      result << current
      queue.concat(current.children.to_a)
    end
    result
  end

  def root?
    parent_id.nil?
  end

  def leaf?
    children.empty?
  end

  def depth
    ancestors.size
  end

  def path
    (ancestors + [self]).map(&:name).join(' > ')
  end

  def path_ids
    (ancestors + [self]).map(&:id)
  end

  # カスタムメソッド
  def active_products
    products.active
  end

  def active_sub_categories
    sub_categories.where(is_active: true)
  end

  # コールバック
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
