import Foundation
import XCTest

public enum TestFixtures {
    public static let oauthTokenExchangeJSON = """
    {
      "token_type": "Bearer",
      "access_token": "vcp_tok_test_abc123456789xyz",
      "refresh_token": "vcp_ref_test_987654321zyx",
      "expires_in": 86400,
      "scope": "deployments:read projects:read usage:read",
      "team_id": "team_alpha_prod_001",
      "user_id": "usr_dev_johndoe_42"
    }
    """
    
    public static let oauthTokenRefreshJSON = """
    {
      "token_type": "Bearer",
      "access_token": "vcp_tok_refreshed_new_999888777",
      "refresh_token": "vcp_ref_rotated_fresh_111222333",
      "expires_in": 86400,
      "scope": "deployments:read projects:read usage:read",
      "team_id": "team_alpha_prod_001",
      "user_id": "usr_dev_johndoe_42"
    }
    """
    
    public static let deploymentsListJSON = """
    {
      "deployments": [
        {
          "uid": "dpl_build_001",
          "name": "nextjs-storefront",
          "url": "nextjs-storefront-git-feat-cart.vercel.app",
          "state": "BUILDING",
          "created": 1725184800000,
          "creator": {
            "username": "alexdeveloper"
          },
          "meta": {
            "githubCommitMessage": "feat(cart): implement one-click checkout modal",
            "githubCommitRef": "feat/checkout-flow",
            "githubCommitSha": "a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e",
            "githubCommitAuthorName": "Alex Rivera"
          },
          "target": "preview"
        },
        {
          "uid": "dpl_ready_002",
          "name": "api-gateway",
          "url": "api-gateway-prod.vercel.app",
          "state": "READY",
          "created": 1725181200000,
          "creator": {
            "username": "sarahops"
          },
          "meta": {
            "githubCommitMessage": "fix: update CORS headers for secure origin",
            "githubCommitRef": "main",
            "githubCommitSha": "f0e1d2c3b4a5968778695a4b3c2d1e0f9a8b7c6d",
            "githubCommitAuthorName": "Sarah Chen"
          },
          "target": "production"
        },
        {
          "uid": "dpl_err_003",
          "name": "docs-portal",
          "url": "docs-portal-git-fix-typo.vercel.app",
          "state": "ERROR",
          "created": 1725177600000,
          "creator": {
            "username": "juniordev"
          },
          "meta": {
            "githubCommitMessage": "docs: update API v2 migration guide",
            "githubCommitRef": "patch-1",
            "githubCommitSha": "1234567890abcdef1234567890abcdef12345678",
            "githubCommitAuthorName": "Junior Dev"
          },
          "target": "preview"
        },
        {
          "uid": "dpl_canc_004",
          "name": "marketing-landing",
          "url": "marketing-landing-preview.vercel.app",
          "state": "CANCELED",
          "created": 1725174000000,
          "creator": {
            "username": "marketingteam"
          },
          "meta": {
            "githubCommitMessage": "chore: cancel redundant staging build",
            "githubCommitRef": "staging",
            "githubCommitSha": "abcdef1234567890abcdef1234567890abcdef12",
            "githubCommitAuthorName": "Marketing Bot"
          },
          "target": "preview"
        },
        {
          "uid": "dpl_queued_005",
          "name": "auth-service",
          "url": "auth-service-staging.vercel.app",
          "state": "QUEUED",
          "created": 1725170400000,
          "creator": {
            "username": "securitylead"
          },
          "meta": {
            "githubCommitMessage": "sec: upgrade argon2 password hasher library",
            "githubCommitRef": "security/argon2-upgrade",
            "githubCommitSha": "9876543210fedcba9876543210fedcba98765432",
            "githubCommitAuthorName": "Security Lead"
          },
          "target": "preview"
        },
        {
          "uid": "dpl_init_006",
          "name": "analytics-worker",
          "url": "analytics-worker-dev.vercel.app",
          "state": "INITIALIZING",
          "created": 1725166800000,
          "creator": {
            "username": "datateam"
          },
          "meta": {
            "githubCommitMessage": "feat: ingest daily active telemetry stream",
            "githubCommitRef": "feature/telemetry",
            "githubCommitSha": "11223344556677889900aabbccddeeff11223344",
            "githubCommitAuthorName": "Data Engineer"
          },
          "target": "preview"
        }
      ],
      "pagination": {
        "count": 6,
        "next": 1725166800000,
        "prev": 1725184800000
      }
    }
    """
    
    public static let deploymentsPaginationPage1JSON = """
    {
      "deployments": [
        {
          "uid": "dpl_page1_item1",
          "name": "dashboard-app",
          "url": "dashboard-app-page1.vercel.app",
          "state": "READY",
          "created": 1725200000000,
          "creator": {
            "username": "lead_frontend"
          },
          "meta": {
            "githubCommitMessage": "page 1 item 1 commit",
            "githubCommitRef": "main",
            "githubCommitSha": "1111111111111111111111111111111111111111",
            "githubCommitAuthorName": "Alice"
          },
          "target": "production"
        },
        {
          "uid": "dpl_page1_item2",
          "name": "dashboard-app",
          "url": "dashboard-app-page1-2.vercel.app",
          "state": "READY",
          "created": 1725190000000,
          "creator": {
            "username": "lead_frontend"
          },
          "meta": {
            "githubCommitMessage": "page 1 item 2 commit",
            "githubCommitRef": "main",
            "githubCommitSha": "2222222222222222222222222222222222222222",
            "githubCommitAuthorName": "Alice"
          },
          "target": "production"
        }
      ],
      "pagination": {
        "count": 2,
        "next": 1725190000000,
        "prev": 1725200000000
      }
    }
    """
    
    public static let deploymentsPaginationPage2JSON = """
    {
      "deployments": [
        {
          "uid": "dpl_page2_item1",
          "name": "dashboard-app",
          "url": "dashboard-app-page2.vercel.app",
          "state": "READY",
          "created": 1725180000000,
          "creator": {
            "username": "lead_frontend"
          },
          "meta": {
            "githubCommitMessage": "page 2 item 1 commit",
            "githubCommitRef": "main",
            "githubCommitSha": "3333333333333333333333333333333333333333",
            "githubCommitAuthorName": "Alice"
          },
          "target": "production"
        }
      ],
      "pagination": {
        "count": 1,
        "next": null,
        "prev": 1725180000000
      }
    }
    """
    
    public static let projectsListJSON = """
    {
      "projects": [
        {
          "id": "prj_storefront_001",
          "name": "nextjs-storefront",
          "framework": "nextjs",
          "link": {
            "type": "github",
            "repo": "nextjs-storefront",
            "org": "acmecorp"
          }
        },
        {
          "id": "prj_gateway_002",
          "name": "api-gateway",
          "framework": "node",
          "link": {
            "type": "github",
            "repo": "api-gateway",
            "org": "acmecorp"
          }
        },
        {
          "id": "prj_docs_003",
          "name": "docs-portal",
          "framework": "docusaurus",
          "link": {
            "type": "github",
            "repo": "docs-portal",
            "org": "acmecorp"
          }
        }
      ]
    }
    """
    
    public static let usageMetricsJSON = """
    {
      "metrics": {
        "bandwidth": {
          "limit": 1073741824000,
          "usage": 214748364800
        },
        "serverlessFunctionExecution": {
          "limit": 1000000,
          "usage": 450000
        },
        "edgeRequests": {
          "limit": 5000000,
          "usage": 1250000
        }
      }
    }
    """
    
    public static let emptyDeploymentsJSON = """
    {
      "deployments": [],
      "pagination": {
        "count": 0,
        "next": null,
        "prev": null
      }
    }
    """
    
    public static let error401UnauthorizedJSON = """
    {
      "error": {
        "code": "unauthorized",
        "message": "Invalid or expired token provided in Authorization header"
      }
    }
    """
    
    public static let error403ForbiddenJSON = """
    {
      "error": {
        "code": "forbidden",
        "message": "User does not have permission to access this team workspace"
      }
    }
    """
    
    public static let error429RateLimitedJSON = """
    {
      "error": {
        "code": "rate_limited",
        "message": "Too many requests. Rate limit exceeded for endpoint /v6/deployments"
      }
    }
    """
    
    public static let error500ServerErrorJSON = """
    {
      "error": {
        "code": "internal_server_error",
        "message": "An unexpected server error occurred while processing the request"
      }
    }
    """
    
    public static func data(from string: String) -> Data {
        return string.data(using: .utf8) ?? Data()
    }
}
