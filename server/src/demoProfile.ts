import type { Profile } from "./domain/profile.js";

export const demoProfile: Profile = {
  id: "ray",
  displayName: "Ray",
  pronoun: "he",
  condition: "Parkinson's disease with dysarthria",
  fields: [
    { key: "fullName", label: "Full name", value: "Ray Kowalski", sensitive: false },
    { key: "dateOfBirth", label: "Date of birth", value: "March 4, 1952", sensitive: false },
    { key: "address", label: "Address", value: "412 Forest Avenue, Ypsilanti, Michigan 48197", sensitive: false },
    { key: "phone", label: "Callback number", value: "734-555-0142", sensitive: false },
    { key: "rxNumber", label: "Prescription number", value: "RX 448-2219", sensitive: false },
    { key: "insuranceMemberId", label: "Insurance member ID", value: "MBR 7731 0094", sensitive: false },
    { key: "ssn", label: "Social security number", value: "6789", sensitive: true },
  ],
  places: [
    {
      id: "pharmacy",
      name: "Nest Street Pharmacy",
      kind: "pharmacy",
      phone: "",
      purpose: "Refill carbidopa-levodopa and ask when it will be ready",
      fieldKeys: ["fullName", "dateOfBirth", "rxNumber", "address"],
    },
    {
      id: "doctor",
      name: "Dr. Patel's office",
      kind: "doctor",
      phone: "",
      purpose: "Confirm the neurology appointment next Tuesday",
      fieldKeys: ["fullName", "dateOfBirth", "insuranceMemberId"],
    },
    {
      id: "caseManager",
      name: "Area Agency on Aging",
      kind: "caseManager",
      phone: "",
      purpose: "Check on the in-home support request",
      fieldKeys: ["fullName", "dateOfBirth", "address", "phone"],
    },
  ],
};
