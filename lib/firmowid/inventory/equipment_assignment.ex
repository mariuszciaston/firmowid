defmodule Firmowid.Inventory.EquipmentAssignment do
  @moduledoc """
  One period a member held a piece of equipment: when and in what condition it
  was issued and returned. An assignment without `returned_on` is open, and a
  piece of equipment has at most one open assignment.

  Admins issue and take back equipment through the domain bypass; an employee
  reads their own assignments.
  """
  use Ash.Resource,
    domain: Firmowid.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  use Gettext, backend: Firmowid.Gettext

  alias Firmowid.Resource

  require Resource

  postgres do
    table "equipment_assignments"
    repo Firmowid.Repo

    references do
      reference :organization, on_delete: :delete
      reference :equipment, on_delete: :delete
      reference :member, on_delete: :delete
    end

    identity_wheres_to_sql one_open_per_equipment: "returned_on IS NULL"
  end

  actions do
    defaults [:read]

    read :list do
      description "List assignments, the latest issued first, optionally of one member or equipment, or only open ones."

      argument :member_id, :uuid
      argument :equipment_id, :uuid
      argument :open_only, :boolean, default: false

      prepare build(sort: [issued_on: :desc, inserted_at: :desc])

      prepare build(filter: expr(member_id == ^arg(:member_id))) do
        where present(:member_id)
      end

      prepare build(filter: expr(equipment_id == ^arg(:equipment_id))) do
        where present(:equipment_id)
      end

      prepare build(filter: expr(is_nil(returned_on))) do
        where argument_equals(:open_only, true)
      end
    end

    create :issue do
      description "Issue available equipment to a member of the organization."
      accept [:equipment_id, :member_id, :issued_on, :issue_note]

      validate Firmowid.Core.Validations.MemberInOrganization
      validate Firmowid.Inventory.Validations.EquipmentAvailable
    end

    update :return do
      description "Take back issued equipment, noting the date and its condition."
      accept [:returned_on, :return_note]
      require_attributes [:returned_on]

      change filter(expr(is_nil(returned_on)))

      validate compare(:returned_on, greater_than_or_equal_to: :issued_on),
        message: gettext_noop("cannot be earlier than the issue date")
    end
  end

  # Writes are left to the domain's admin bypass.
  policies do
    policy action_type(:read) do
      authorize_if expr(member_id == ^actor([:member, :id]))
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :issued_on, :date do
      public? true
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :issue_note, :string do
      public? true
      constraints max_length: 500
    end

    attribute :returned_on, :date, public?: true

    attribute :return_note, :string do
      public? true
      constraints max_length: 500
    end

    Resource.firmowid_timestamps()
  end

  relationships do
    belongs_to :organization, Firmowid.Core.Organization do
      allow_nil? false
    end

    belongs_to :equipment, Firmowid.Inventory.Equipment do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :member, Firmowid.Core.Member do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    # Two admins issuing the same equipment at once: the partial unique index
    # lets only one of them through.
    identity :one_open_per_equipment, [:equipment_id] do
      where expr(is_nil(returned_on))
      message gettext_noop("is already issued to someone")
    end
  end
end
