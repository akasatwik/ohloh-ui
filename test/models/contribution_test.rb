require 'test_helper'

class ContributionTest < ActiveSupport::TestCase
  before do
    @person = create(:person)
    @contribution = @person.contributions.first
    @contributor_fact = @contribution.contributor_fact
    @analysis_alias = create(:analysis_alias, preferred_name_id: @person.name_fact.name_id,
                                              analysis_id: @contributor_fact.analysis_id,
                                              commit_name_id: @contributor_fact.name_id)
  end

  describe '#sort_by' do
    before do
      create_people_for_sort_by
    end

    it '#name' do
      find_contribution(:person, 'name').must_equal [@person2.id, @person1.id, @person3.id]
    end

    it '#kudo_position' do
      find_contribution(:person, 'kudo_position')
        .must_equal [@person3.id, @person2.id, @person1.id]
    end

    it '#commits' do
      find_contribution(:contributor_fact, 'commits')
        .must_equal [@person1.id, @person2.id, @person3.id]
    end

    it '#twelve_month_commits' do
      find_contribution(:contributor_fact, 'twelve_month_commits')
        .must_equal [@person3.id, @person2.id, @person1.id]
    end

    it '#latest_commit' do
      find_contribution(:contributor_fact, 'latest_commit')
        .must_equal [@person3.id, @person2.id, @person1.id]
    end

    it '#newest' do
      find_contribution(:contributor_fact, 'newest')
        .must_equal [@person3.id, @person2.id, @person1.id]
    end
  end

  describe '#filter_by' do
    it 'filter_by with query string' do
      create_people_for_sort_by
      Contribution.filter_by('AA test').count.must_equal 1
      Contribution.filter_by('AA test').first.must_equal @person2.contributions.first
    end

    it 'filter_by with nil string' do
      Contribution.filter_by(nil).count.must_equal Contribution.count
    end
  end

  describe '#analysis_aliases' do
    it 'must return empty array if contributor_fact is nil' do
      Contribution.first.analysis_aliases.must_equal []
    end

    it 'must return analysis_aliases if contributor_fact is present' do
      @contribution.analysis_aliases.first.must_equal @analysis_alias
    end
  end

  describe '#scm_names' do
    it 'must return committers name' do
      @contribution.scm_names.must_equal [@analysis_alias.commit_name]
    end

    it 'must return empty array if contributor_fact is nil' do
      Contribution.first.scm_names.must_equal []
    end
  end

  describe '#committer_name' do
    it 'must return contributors name' do
      @contribution.committer_name.must_equal @contributor_fact.name.name
    end

    it 'must return persons effective_name if zero contributors' do
      Contribution.first.committer_name.must_equal Contribution.first.person.effective_name
    end
  end

  it '#generate_id_from_project_id_and_name_id' do
    Contribution.generate_id_from_project_id_and_name_id(1, 1).must_equal 644_245_094_5
  end

  it '#generate_id_from_project_id_and_account_id' do
    Contribution.generate_id_from_project_id_and_account_id(1, 1).must_equal 429_496_729_7
  end

  it '#generate_project_id_and_name_id_from_id' do
    Contribution.generate_project_id_and_name_id_from_id(1).must_equal [0, 1]
  end

  it 'recent_kudos must return kudos' do
    kudo = create(:kudo, project_id: @person.project_id, name_id: @person.name_fact.name_id)
    @contribution.recent_kudos.count.must_equal 1
    @contribution.recent_kudos.first.must_equal kudo
  end

  private

  def create_people_for_sort_by
    Person.update_all(kudo_position: 10)
    ContributorFact.update_all(commits: nil, twelve_month_commits: nil,
                               last_checkin: nil, first_checkin: (Time.now - 5.years))
    @person1 = create(:person, effective_name: 'AB test', kudo_position: 3)
    @person1.contributor_fact.update_columns(commits: 10, twelve_month_commits: 3,
                                             last_checkin: Time.now, first_checkin: Time.now)
    @person2 = create(:person, effective_name: 'AA test', kudo_position: 2)
    @person2.contributor_fact.update_columns(commits: 9, twelve_month_commits: 4,
                                             last_checkin: Time.now + 1, first_checkin: Time.now + 1)
    @person3 = create(:person, effective_name: 'AC test', kudo_position: 1)
    @person3.contributor_fact.update_columns(commits: 8, twelve_month_commits: 5,
                                             last_checkin: Time.now + 2, first_checkin: Time.now + 2)
  end

  def find_contribution(join, sort_by)
    Contribution.joins(join).send("sort_by_#{sort_by}").limit(3).pluck(:id)
  end
end