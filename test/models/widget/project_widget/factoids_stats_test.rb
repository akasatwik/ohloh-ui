require 'test_helper'

class FactoidsStatsTest < ActiveSupport::TestCase
  let(:project) { create(:project) }
  let(:widget) { ProjectWidget::FactoidsStats.new(project_id: project.id) }

  describe 'height' do
    it 'should return 250' do
      widget.height.must_equal 250
    end
  end

  describe 'width' do
    it 'should return 370' do
      widget.width.must_equal 370
    end
  end

  describe 'title' do
    it 'should return the title' do
      widget.title.must_equal I18n.t('project_widgets.factoids_stats.title')
    end
  end

  describe 'short_nice_name' do
    it 'should return the short_nice_name' do
      widget.short_nice_name.must_equal I18n.t('project_widgets.factoids_stats.short_nice_name')
    end
  end

  describe 'position' do
    it 'should return 1' do
      widget.position.must_equal 1
    end
  end
end
