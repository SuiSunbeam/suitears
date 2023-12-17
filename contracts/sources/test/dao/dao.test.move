#[test_only]
module suitears::dao_tests {
  use std::option;
  use std::type_name;

  use sui::object;
  use sui::transfer;
  use sui::clock::{Self, Clock};
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, burn_for_testing, mint_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};


  use suitears::s_eth::{Self, S_ETH};
  use suitears::dao::{Self, Dao, Proposal};
  use suitears::dao_treasury::DaoTreasury;
  use suitears::test_utils::{people, scenario};


    /// Proposal state
  const PENDING: u8 = 1;
  const ACTIVE: u8 = 2;
  const DEFEATED: u8 = 3;
  const AGREED: u8 = 4;
  const QUEUED: u8 = 5;
  const EXECUTABLE: u8 = 6;
  const EXTRACTED: u8 = 7;

  const DAO_VOTING_DELAY: u64 = 10;
  const DAO_VOTING_PERIOD: u64 = 20;  
  const DAO_QUORUM_RATE: u64 = 7_00_000_000;
  const DAO_MIN_ACTION_DELAY: u64 = 7;
  const DAO_MIN_QUORUM_VOTES: u64 = 1234;

  const PROPOSAL_ACTION_DELAY: u64 = 11;
  const PROPOSAL_QUORUM_VOTES: u64 = 2341;

  struct InterestDAO has drop {}

  struct AuthorizedWitness has drop {}

  #[test]
  #[lint_allow(share_owned)]
  fun initiates_correctly() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    // Dao is initialized correctly
    next_tx(test, alice);  
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      let treasury = test::take_shared<DaoTreasury<InterestDAO>>(test);

      assert_eq(dao::voting_delay(&dao), DAO_VOTING_DELAY);
      assert_eq(dao::voting_period(&dao), DAO_VOTING_PERIOD);
      assert_eq(dao::dao_voting_quorum_rate(&dao), DAO_QUORUM_RATE);
      assert_eq(dao::min_action_delay(&dao), DAO_MIN_ACTION_DELAY);
      assert_eq(dao::min_quorum_votes(&dao), DAO_MIN_QUORUM_VOTES);
      assert_eq(dao::treasury(&dao), object::id(&treasury));
      assert_eq(dao::dao_coin_type(&dao), type_name::get<S_ETH>());

      test::return_shared(treasury);
      test::return_shared(dao);
    };

    // Test proposal
    next_tx(test, alice);
    {
      let dao = test::take_shared<Dao<InterestDAO>>(test);
      
      clock::increment_for_testing(&mut c, 123);

      let proposal = dao::propose(
        &mut dao,
        &c,
        type_name::get<AuthorizedWitness>(),
        option::none(),
        PROPOSAL_ACTION_DELAY,
        PROPOSAL_QUORUM_VOTES,
        vector[1],
        ctx(test)
      );

      assert_eq(dao::proposer(&proposal), alice);
      assert_eq(dao::start_time(&proposal), 123 + DAO_VOTING_DELAY);
      assert_eq(dao::end_time(&proposal), 123 + DAO_VOTING_DELAY + DAO_VOTING_PERIOD);
      assert_eq(dao::for_votes(&proposal), 0);
      assert_eq(dao::against_votes(&proposal), 0);
      assert_eq(dao::eta(&proposal), 0);
      assert_eq(dao::quorum_votes(&proposal), PROPOSAL_QUORUM_VOTES);
      assert_eq(dao::voting_quorum_rate(&proposal), DAO_QUORUM_RATE);
      assert_eq(dao::hash(&proposal), vector[1]);
      assert_eq(dao::authorized_witness(&proposal), type_name::get<AuthorizedWitness>());
      assert_eq(dao::capability_id(&proposal), option::none());
      assert_eq(dao::coin_type(&proposal), type_name::get<S_ETH>());

      transfer::public_share_object(proposal);
      test::return_shared(dao);
    };

    // test votes
    next_tx(test, alice);
    {
      let proposal = test::take_shared<Proposal<InterestDAO>>(test);
      clock::increment_for_testing(&mut c, DAO_VOTING_DELAY + 1);

      let vote = dao::cast_vote<InterestDAO, S_ETH>(
        &mut proposal,
        &c,
        mint_for_testing(123, ctx(test)),
        true,
        ctx(test)
      );

      assert_eq(dao::balance(&vote), 123);
      assert_eq(dao::proposal_id(&vote), object::id(&proposal));
      assert_eq(dao::vote_end_time(&vote), 123 + DAO_VOTING_DELAY + DAO_VOTING_PERIOD);
      assert_eq(dao::agree(&vote), true);
      assert_eq(dao::proposal_state(&proposal, &c), ACTIVE);

      transfer::public_transfer(vote, alice);

      test::return_shared(proposal);
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  }   

  #[test]
  fun test_end_to_end_not_executable_proposal() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    set_up(test);

    next_tx(test, alice);  
    {

    };
    clock::destroy_for_testing(c);
    test::end(scenario);
  }  

  #[lint_allow(share_owned)]
  fun set_up(test: &mut Scenario) {

    let (alice, _) = people();
    next_tx(test, alice);
    {
      let (dao, treasury) = dao::new_for_testing<InterestDAO, S_ETH>(
        DAO_VOTING_DELAY,
        DAO_VOTING_PERIOD,
        DAO_QUORUM_RATE,
        DAO_MIN_ACTION_DELAY,
        DAO_MIN_QUORUM_VOTES,
        ctx(test)
      );
      
      transfer::public_share_object(dao);
      transfer::public_share_object(treasury);
    };
  }

}