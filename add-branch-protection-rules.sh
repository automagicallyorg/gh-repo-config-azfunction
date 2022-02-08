function createGithubBranchRule {
    local repoName="$1"
    local branch="$2"

    requiresApprovingReviews=true
    dismissesStaleReviews=true
    requiredApprovingReviewCount=1
    isAdminEnforced=true
    requiresConversationResolution=true

    branchRuleId=$(gh api graphql -f query='
        query checkBranchRules($org:String!,$repo:String!) {
            repository(owner:$org, name:$repo) { 
            branchProtectionRules(first: 100) { 
                nodes { 
                    pattern,
                    id
                    }
                }
            }
        }' -f org="$GITHUB_ORG" -f repo="$repoName" --jq ".data.repository.branchProtectionRules.nodes.[] | select(.pattern==\"$branch\") | .id")

    if [ ! -z $branchRuleId ]; then
        echo "Matching branch rule for \"$branch\" pattern already exist: $branchRuleId. Updating..." >&2
        branchRule=$(gh api graphql -f query='
        mutation($branchRuleId:ID!,$branch:String!,$requiresApprovingReviews:Boolean!,$requiredApprovingReviewCount:Int!,$dismissesStaleReviews:Boolean!,$isAdminEnforced:Boolean!,$requiresConversationResolution:Boolean!) {
        updateBranchProtectionRule(input: {
            branchProtectionRuleId: $branchRuleId
            pattern: $branch
            requiresApprovingReviews: $requiresApprovingReviews
            requiredApprovingReviewCount: $requiredApprovingReviewCount
            dismissesStaleReviews: $dismissesStaleReviews
            isAdminEnforced: $isAdminEnforced
            requiresConversationResolution: $requiresConversationResolution
        }) { clientMutationId }
        }' -f branchRuleId="$branchRuleId" -f branch="$branch" -F requiresApprovingReviews=$requiresApprovingReviews -F requiredApprovingReviewCount=$requiredApprovingReviewCount -F dismissesStaleReviews=$dismissesStaleReviews -F isAdminEnforced=$isAdminEnforced -F requiresConversationResolution=$requiresConversationResolution)
    else
        echo "Matching branch rule for \"$branch\" pattern does not exist. Creating..." >&2
        branchRule=$(gh api graphql -f query='
        mutation($repositoryId:ID!,$branch:String!,$requiresApprovingReviews:Boolean!,$requiredApprovingReviewCount:Int!,$dismissesStaleReviews:Boolean!,$isAdminEnforced:Boolean!,$requiresConversationResolution:Boolean!) {
        createBranchProtectionRule(input: {
            repositoryId: $repositoryId
            pattern: $branch
            requiresApprovingReviews: $requiresApprovingReviews
            requiredApprovingReviewCount: $requiredApprovingReviewCount
            dismissesStaleReviews: $dismissesStaleReviews
            isAdminEnforced: $isAdminEnforced
            requiresConversationResolution: $requiresConversationResolution
        }) { clientMutationId }
        }' -f repositoryId="$repoId" -f branch="$branch" -F requiresApprovingReviews=$requiresApprovingReviews -F requiredApprovingReviewCount=$requiredApprovingReviewCount -F dismissesStaleReviews=$dismissesStaleReviews -F isAdminEnforced=$isAdminEnforced -F requiresConversationResolution=$requiresConversationResolution)
    fi
}

GITHUB_ORG="automagicallyorg"
policy_branch="main"

orgRepos=$(gh repo list ${GITHUB_ORG} --json name --jq ".[] | select(.name!=\"gh-repo-config-azfunction\") | select(.name!=\".github\") | .name")

for orgRepo in $(echo $orgRepos); do
    echo "updating $orgRepo repo"
    # createGithubBranchRule "$orgRepo" "$policy_branch"
done
