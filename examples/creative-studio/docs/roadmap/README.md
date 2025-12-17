# Roadmap & Future Work

Planned features, enhancements, and future integration strategies.

## ⚠️ IMPORTANT: START HERE

### **[📌 IMPLEMENTATION_STRATEGY_MASTER_INDEX.md](IMPLEMENTATION_STRATEGY_MASTER_INDEX.md)** ← Master document with everything

All roadmap work centers around **3-Phase Authentication Evolution**. The master index explains:
- ✅ Current status and blockers
- ✅ How the 3 phases connect
- ✅ Reading paths by scenario
- ✅ Document relationships

**Don't read this README first - read the master index!**

---

## 📍 Current Application Status

✅ **Production Ready (v1.0)**
- Core features fully implemented
- Cloud SQL PostgreSQL integrated
- Multi-tenant workspaces operational
- All Vertex AI APIs integrated
- CI/CD pipeline automated

**Next Priority**: Phase 1 authentication architecture refactoring (blocks Phase 2 & 3)

---

## 🗂️ Folder Structure

### **Phase 1: Architecture Prerequisite** 🚨 BLOCKING
📁 **[okta_auth/](./okta_auth/)**
- **Read first**: `03_CURRENT_AUTHENTICATION_ISSUES.md` (problem analysis)
- **Then**: `04_DEMO_APP_COMPARISON.md` (solution)
- **Status**: Critical blocker for Phase 2 & 3
- **Timeline**: 1-2 weeks refactoring

### **Phase 2: OIDC + Groups Support**
📁 **[authentication_options/](./authentication_options/)**
- **Start**: `README.md` (overview)
- **Then**: `01_AUTHENTICATION_COMPARISON.md` (compare 3 approaches)
- **For implementation**: `02_FIREBASE_OIDC_IMPLEMENTATION_GUIDE.md`
- **Status**: Blocked by Phase 1
- **Timeline**: 1-2 weeks (after Phase 1)

### **Phase 3: Enterprise Auto-Provisioning** (Optional)
📁 **[auto_provisioning/](./auto_provisioning/)**
- **Quick decision**: `02_QUICK_REFERENCE_DECISION_GUIDE.md` (10 min)
- **Business case**: `03_SECURITY_AND_COST_ANALYSIS.md` (cost/ROI)
- **Implementation**: `04_IMPLEMENTATION_OPTIONS.md` (4 options)
- **Status**: Research complete, blocked by Phase 1 & 2
- **Timeline**: 1-3 weeks (after Phase 1 & 2)
- **Cost risk**: $50,000+/month if not controlled

---

## 📚 Learn More & Next Steps

- **Master Index**: [IMPLEMENTATION_STRATEGY_MASTER_INDEX.md](IMPLEMENTATION_STRATEGY_MASTER_INDEX.md) - Read this first!
- **Phase 1 (BLOCKING)**: [okta_auth/README.md](./okta_auth/README.md)
- **Phase 2 (depends on 1)**: [authentication_options/README.md](./authentication_options/README.md)
- **Phase 3 (depends on 1 & 2)**: [auto_provisioning/README.md](./auto_provisioning/README.md)

---

## 🔗 Related Documentation

- **Main docs**: [../README.md](../README.md)
- **Current features**: [../09-features/](../09-features/)
- **Architecture**: [../02-architecture/01_SYSTEM_DESIGN.md](../02-architecture/01_SYSTEM_DESIGN.md)
- **Security**: [../05-security/01_ACCESS_CONTROL_AND_RBAC.md](../05-security/01_ACCESS_CONTROL_AND_RBAC.md)
