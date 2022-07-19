defmodule ExBanking.Core.User do
  @moduledoc false

  @type t :: %__MODULE__{}
  @enforce_keys ~w(user)a

  defstruct user: nil,
            funds: %{}

  @spec new(String.t()) :: %{:__struct__ => atom}
  def new(user) do
    fields = %{
      user: String.downcase(user),
      funds: %{}
    }

    struct!(__MODULE__, fields)
  end
end
